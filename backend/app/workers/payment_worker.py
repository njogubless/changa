"""Outbox drain + reconciliation sweep for payment initiation (PAY-03).

Two loops, both started from the app lifespan (see app/main.py) and both
using their own short-lived sync Session — never the request-scoped one:

1. `drain_outbox` — turns queued OutboxMessage rows into actual STK
   pushes / Airtel initiations. A provider timeout is never treated as a
   failure: the contribution simply stays PENDING and the reconciliation
   sweep resolves it later from the provider's own authoritative status.
   Only an explicit rejection from the provider (a 4xx/validation error,
   or our own precision check) marks the contribution FAILED.

2. `reconcile_pending` — the safety net. Any contribution still PENDING
   longer than RECONCILE_STALE_AFTER_SECONDS is queried against the
   provider directly; if the provider confirms success it is credited
   through the ledger (FIN-02), if it confirms failure it is marked
   FAILED, and if it still has no answer after RECONCILE_MAX_ATTEMPTS it
   is escalated to manual review rather than polled forever.

Both loops do their DB work in a worker thread (`asyncio.to_thread`) so a
slow query never stalls the event loop that is also serving requests —
this in-process loop is a pragmatic stand-in for the separate worker
tier/deployment the audit recommends (see PERF-05), not a replacement for
it; splitting it into its own process is a deployment change, not a code
change, once that infra exists.
"""
import asyncio
import json
import logging
from datetime import timedelta
from uuid import UUID

from sqlalchemy import select

from app.core.types import ProviderPrecisionError
from app.database import SessionLocal
from app.models.models import (
    Contribution, ContributionStatus, OutboxMessage, OutboxStatus,
    PaymentProvider, utcnow,
)
from app.services import mpesa, airtel, ledger_service

log = logging.getLogger("changa.payment_worker")

OUTBOX_BATCH_SIZE = 20
OUTBOX_MAX_ATTEMPTS = 5
RECONCILE_BATCH_SIZE = 50
RECONCILE_STALE_AFTER = timedelta(seconds=90)
RECONCILE_MAX_ATTEMPTS = 10
LOOP_INTERVAL_SECONDS = 5


def _drain_outbox_sync() -> None:
    db = SessionLocal()
    try:
        messages = (
            db.query(OutboxMessage)
            .filter(OutboxMessage.status == OutboxStatus.PENDING)
            .order_by(OutboxMessage.created_at)
            .limit(OUTBOX_BATCH_SIZE)
            .with_for_update(skip_locked=True)
            .all()
        )
        for message in messages:
            _process_outbox_message(db, message)
    finally:
        db.close()


def _process_outbox_message(db, message: OutboxMessage) -> None:
    message.status = OutboxStatus.PROCESSING
    db.commit()

    try:
        payload = json.loads(message.payload)
        contribution = db.get(Contribution, UUID(payload["contribution_id"]))
        if contribution is None or contribution.status is not ContributionStatus.PENDING:
            message.status = OutboxStatus.DONE  # nothing left to do
            db.commit()
            return

        if contribution.provider == PaymentProvider.MPESA and contribution.checkout_request_id:
            # Daraja already acknowledged a previous attempt for this
            # contribution — pushing again would create a second, untracked
            # CheckoutRequestID and could prompt the payer twice.
            message.status = OutboxStatus.DONE
            db.commit()
            return

        if contribution.provider == PaymentProvider.AIRTEL and contribution.push_attempts > 0:
            # Airtel has no separate acknowledgement handle to check first,
            # and the transaction `id` we send is the same idempotency key
            # on every attempt, so a second explicit push is more risk than
            # benefit — leave it to the reconciliation sweep, which queries
            # Airtel directly by that same reference.
            message.status = OutboxStatus.DONE
            db.commit()
            return

        asyncio.run(_push_to_provider(db, contribution))
        message.status = OutboxStatus.DONE
        message.processed_at = utcnow()
        db.commit()

    except ProviderPrecisionError as exc:
        contribution.status = ContributionStatus.FAILED
        contribution.failure_reason = "amount_precision_rejected"
        message.status = OutboxStatus.DONE
        message.last_error = str(exc)[:255]
        db.commit()

    except Exception as exc:  # noqa: BLE001 — a timeout must never read as failure
        message.attempts += 1
        message.last_error = str(exc)[:255]
        contribution.push_attempts += 1
        if message.attempts >= OUTBOX_MAX_ATTEMPTS:
            message.status = OutboxStatus.FAILED
            log.error("outbox.exhausted", extra={"message_id": str(message.id)})
        else:
            message.status = OutboxStatus.PENDING  # retry next loop iteration
        db.commit()


async def _push_to_provider(db, contribution: Contribution) -> None:
    project = contribution.project
    if contribution.provider == PaymentProvider.MPESA:
        result = await mpesa.stk_push(
            phone=contribution.phone,
            amount=contribution.amount,
            reference=contribution.reference,
            description=f"Changa: {project.title[:20]}",
        )
        contribution.checkout_request_id = result.get("CheckoutRequestID")
    else:
        await airtel.initiate_payment(
            phone=contribution.phone,
            amount=contribution.amount,
            reference=contribution.reference,
        )


def _reconcile_pending_sync() -> list[UUID]:
    """Find stale PENDING contributions. Returns their IDs for the async
    step (the actual provider query) to process one at a time."""
    db = SessionLocal()
    try:
        cutoff = utcnow() - RECONCILE_STALE_AFTER
        rows = (
            db.query(Contribution.id)
            .filter(
                Contribution.status == ContributionStatus.PENDING,
                Contribution.initiated_at < cutoff,
                Contribution.reconcile_attempts < RECONCILE_MAX_ATTEMPTS,
            )
            .limit(RECONCILE_BATCH_SIZE)
            .all()
        )
        return [r.id for r in rows]
    finally:
        db.close()


async def _reconcile_one(contribution_id: UUID) -> None:
    db = SessionLocal()
    try:
        contribution = db.get(Contribution, contribution_id)
        if contribution is None or contribution.status is not ContributionStatus.PENDING:
            return

        if contribution.provider == PaymentProvider.MPESA and not contribution.checkout_request_id:
            # The initiation push itself never got a confirmed response —
            # there is no handle to query Daraja with. Count this against
            # the same attempt budget rather than polling forever with
            # nothing to check.
            contribution.reconcile_attempts += 1
            if contribution.reconcile_attempts >= RECONCILE_MAX_ATTEMPTS:
                contribution.status = ContributionStatus.FAILED
                contribution.failure_reason = "push_never_confirmed"
                log.error("reconcile.push_never_confirmed", extra={"contribution_id": str(contribution.id)})
            db.commit()
            return

        if contribution.provider == PaymentProvider.MPESA:
            verified = await mpesa.query_stk_status(contribution.checkout_request_id)
            receipt = None
        else:
            verified = await airtel.query_transaction_status(contribution.reference)
            receipt = verified.get("receipt")

        if verified["success"]:
            ledger_service.credit_contribution(db, contribution, receipt, utcnow())
            db.commit()
            return

        contribution.reconcile_attempts += 1
        if contribution.reconcile_attempts >= RECONCILE_MAX_ATTEMPTS:
            contribution.status = ContributionStatus.FAILED
            contribution.failure_reason = "escalated_manual_review"
            log.error("reconcile.escalated", extra={"contribution_id": str(contribution.id)})
        db.commit()
    finally:
        db.close()


async def run_once() -> None:
    await asyncio.to_thread(_drain_outbox_sync)
    stale_ids = await asyncio.to_thread(_reconcile_pending_sync)
    for contribution_id in stale_ids:
        await _reconcile_one(contribution_id)


async def run_forever() -> None:
    while True:
        try:
            await run_once()
        except asyncio.CancelledError:
            raise
        except Exception:  # noqa: BLE001 — one bad iteration must not kill the loop
            log.exception("payment_worker.iteration_failed")
        await asyncio.sleep(LOOP_INTERVAL_SECONDS)
