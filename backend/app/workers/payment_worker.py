"""Outbox drain + reconciliation sweep for payment initiation (PAY-03).

Two loops, both started from the app lifespan (see app/main.py) and both
using their own short-lived sync Session — never the request-scoped one:

1. `drain_outbox` — turns queued OutboxMessage rows into actual STK
   pushes / Airtel initiations. What happens on error depends on whether
   the request could have reached the provider (app/services/provider_errors.py):
   - retryable (never sent: connect error, OAuth failure) -> retried on the
     next loop; once OUTBOX_MAX_ATTEMPTS is exhausted the contribution is
     FAILED, because no prompt was ever sent.
   - rejected (the provider answered and refused, or our precision check)
     -> contribution FAILED.
   - ambiguous (read timeout, gateway 5xx, dropped connection, any
     unexpected exception) -> never re-pushed, since a second push can
     charge the payer twice. The contribution stays PENDING for the sweep.

2. `reconcile_pending` — the safety net. Any contribution still PENDING
   longer than RECONCILE_STALE_AFTER is queried against the provider
   directly: SUCCESS is credited through the ledger (FIN-02), a definitive
   FAILED is marked FAILED, and UNKNOWN is asked again. After
   RECONCILE_MAX_ATTEMPTS without a definitive answer the contribution is
   left PENDING with failure_reason = NEEDS_REVIEW and drops out of the
   sweep — it is never turned into FAILED on a guess, because the payer
   may well have paid. Ops query: status = 'PENDING' AND
   failure_reason = 'needs_manual_review'.

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

from app.core.types import ProviderPrecisionError
from app.database import SessionLocal
from app.models.models import (
    Contribution, ContributionStatus, OutboxMessage, OutboxStatus,
    PaymentProvider, utcnow,
)
from app.services import mpesa, airtel, ledger_service
from app.services.provider_errors import (
    ProviderOutcome, ProviderAmbiguousError, ProviderRejectedError, ProviderRetryableError,
)

log = logging.getLogger("changa.payment_worker")

OUTBOX_BATCH_SIZE = 20
OUTBOX_MAX_ATTEMPTS = 5
RECONCILE_BATCH_SIZE = 50
RECONCILE_STALE_AFTER = timedelta(seconds=90)
RECONCILE_MAX_ATTEMPTS = 10
LOOP_INTERVAL_SECONDS = 5

NEEDS_REVIEW = "needs_manual_review"


def _claim_next_message(db, skip_ids: list[UUID]) -> OutboxMessage | None:
    """Lock one PENDING message, flip it to PROCESSING and commit.

    One at a time on purpose: the previous version locked a batch of 20
    with FOR UPDATE SKIP LOCKED and then committed after the first, which
    released the locks on the other 19 while this worker still meant to
    process them — a second worker (another uvicorn worker process or
    replica) could then claim and push the same contributions. Committing
    PROCESSING under the row lock is the claim itself.

    `skip_ids` holds messages already handled in this pass, so a retryable
    failure is retried on the next loop iteration rather than immediately.
    """
    query = db.query(OutboxMessage).filter(OutboxMessage.status == OutboxStatus.PENDING)
    if skip_ids:
        query = query.filter(OutboxMessage.id.notin_(skip_ids))
    message = (
        query.order_by(OutboxMessage.created_at)
        .limit(1)
        .with_for_update(skip_locked=True)
        .first()
    )
    if message is None:
        return None
    message.status = OutboxStatus.PROCESSING
    db.commit()
    return message


def _drain_outbox_sync() -> None:
    db = SessionLocal()
    try:
        handled: list[UUID] = []
        for _ in range(OUTBOX_BATCH_SIZE):
            message = _claim_next_message(db, handled)
            if message is None:
                break
            handled.append(message.id)
            _process_outbox_message(db, message)
    finally:
        db.close()


def _process_outbox_message(db, message: OutboxMessage) -> None:
    contribution = None
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
            # A previous push may have reached Airtel. The transaction `id`
            # we send is our reference, so the reconciliation sweep can
            # always ask Airtel about it directly — no second push needed.
            message.status = OutboxStatus.DONE
            db.commit()
            return

        asyncio.run(_push_to_provider(db, contribution))
        message.status = OutboxStatus.DONE
        message.processed_at = utcnow()
        db.commit()

    except ProviderRetryableError as exc:
        db.rollback()
        message.attempts += 1
        message.last_error = str(exc)[:255]
        if message.attempts >= OUTBOX_MAX_ATTEMPTS:
            message.status = OutboxStatus.FAILED
            if contribution is not None:
                ledger_service.fail_contribution(db, contribution, "push_not_sent")
            log.error("outbox.exhausted", extra={"message_id": str(message.id)})
        else:
            message.status = OutboxStatus.PENDING  # retry next loop iteration
        db.commit()

    except (ProviderRejectedError, ProviderPrecisionError) as exc:
        db.rollback()
        reason = (
            "amount_precision_rejected" if isinstance(exc, ProviderPrecisionError)
            else f"provider_rejected: {exc}"
        )
        if contribution is not None:
            ledger_service.fail_contribution(db, contribution, reason)
        message.status = OutboxStatus.DONE
        message.last_error = str(exc)[:255]
        db.commit()

    except Exception as exc:  # noqa: BLE001 — ProviderAmbiguousError, or a bug
        # The push may have been created. Never retry it and never fail the
        # contribution on a guess; the reconciliation sweep queries the
        # provider (or escalates to manual review if there is no handle).
        db.rollback()
        if contribution is not None:
            contribution.push_attempts += 1
        message.status = OutboxStatus.FAILED
        message.last_error = f"ambiguous: {exc}"[:255]
        db.commit()
        log.error(
            "outbox.ambiguous",
            extra={"message_id": str(message.id), "error_type": type(exc).__name__},
        )


async def _push_to_provider(db, contribution: Contribution) -> None:
    project = contribution.project
    if contribution.provider == PaymentProvider.MPESA:
        result = await mpesa.stk_push(
            phone=contribution.phone,
            amount=contribution.amount,
            reference=contribution.reference,
            description=f"Changa: {project.title[:20]}",
        )
        contribution.checkout_request_id = result["CheckoutRequestID"]
    else:
        await airtel.initiate_payment(
            phone=contribution.phone,
            amount=contribution.amount,
            reference=contribution.reference,
        )
    contribution.push_attempts += 1


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


def _record_unresolved(db, contribution: Contribution, log_event: str) -> None:
    contribution.reconcile_attempts += 1
    if contribution.reconcile_attempts >= RECONCILE_MAX_ATTEMPTS:
        # Out of automatic attempts with no definitive answer. Stays PENDING
        # (the payer may have paid) and leaves the sweep; a human resolves it.
        contribution.failure_reason = NEEDS_REVIEW
        log.error(log_event, extra={"contribution_id": str(contribution.id)})


async def _reconcile_one(contribution_id: UUID) -> None:
    db = SessionLocal()
    try:
        contribution = db.get(Contribution, contribution_id)
        if contribution is None or contribution.status is not ContributionStatus.PENDING:
            return

        if contribution.provider == PaymentProvider.MPESA and not contribution.checkout_request_id:
            # The push was never acknowledged with a CheckoutRequestID, so
            # there is no handle to query Daraja with. A raw callback for it
            # (if the payer did pay) is still kept in provider_events.
            _record_unresolved(db, contribution, "reconcile.push_never_confirmed")
            db.commit()
            return

        if contribution.provider == PaymentProvider.MPESA:
            verified = await mpesa.query_stk_status(contribution.checkout_request_id)
            receipt = None
        else:
            verified = await airtel.query_transaction_status(contribution.reference)
            receipt = verified.get("receipt")

        if verified["outcome"] is ProviderOutcome.SUCCESS:
            ledger_service.credit_contribution(db, contribution, receipt, utcnow())
        elif verified["outcome"] is ProviderOutcome.FAILED:
            ledger_service.fail_contribution(db, contribution, verified.get("reason") or "provider_failed")
        else:
            _record_unresolved(db, contribution, "reconcile.escalated")
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
