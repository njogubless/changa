import hmac
import json
import secrets
from datetime import datetime, timedelta, timezone
from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException, Query, Request
from sqlalchemy.orm import Session

from app.database import get_db
from app.core.config import settings
from app.core.security import get_current_user
from app.core.ratelimit import check_rate_limit
from app.core.observability import get_logger
from app.models.models import (
    User, Project, Contribution, ContributionStatus, PaymentProvider,
    ChamaMember, ProviderEvent, OutboxMessage,
)

from app.schemas.projects import (
    MpesaContributeRequest, AirtelContributeRequest,
    ContributionResponse, ContributionStatusResponse,
)
from app.services import mpesa, airtel, ledger_service
from app.services.provider_errors import ProviderOutcome

DAILY_CONTRIBUTION_CAP = 20

router = APIRouter(tags=["Payments"])
log = get_logger("changa.payments")


def _generate_reference(prefix: str) -> str:
    # 16 bytes (128 bits) — the previous 4 bytes (32 bits, ~4.3B values) was
    # brute-forceable in bulk against an unthrottled endpoint (see PAY-01,
    # SEC-03). This reference is also returned to the payer in the 201
    # response, so it must never be the only thing standing between an
    # attacker and a forged callback — see the checkout_request_id handling
    # below for why the callback path no longer trusts it for that purpose.
    return f"{prefix}-{secrets.token_hex(16).upper()}"


def _get_active_project(project_id: UUID, db: Session) -> Project:
    project = db.query(Project).filter(Project.id == project_id).first()
    if not project:
        raise HTTPException(status_code=404, detail="Project not found")
    if project.status != "active":
        raise HTTPException(status_code=400, detail="Project is not accepting contributions")
    return project


def _assert_chama_member(project: Project, user: User, db: Session) -> None:
    is_member = db.query(ChamaMember).filter(
        ChamaMember.chama_id == project.chama_id,
        ChamaMember.user_id == user.id,
    ).first()
    if not is_member:
        raise HTTPException(status_code=403, detail="You must be a Chama member to contribute")


def _assert_under_daily_cap(user: User, db: Session) -> None:
    """A per-request rate limit alone doesn't bound total daily provider
    cost — this does. Each initiation triggers a real STK push billed to
    the platform; with no cap, an unthrottled loop of small contributions
    is unlimited spend, not just an inconvenience. See SEC-03.

    Restored: the definition was dropped while resolving the conflict in
    merge 54a9724 but both call sites survived, so every contribution
    request raised NameError (HTTP 500)."""
    since = datetime.now(timezone.utc) - timedelta(hours=24)
    count = (
        db.query(Contribution)
        .filter(Contribution.user_id == user.id, Contribution.initiated_at >= since)
        .count()
    )
    if count >= DAILY_CONTRIBUTION_CAP:
        raise HTTPException(
            status_code=429,
            detail=f"Daily contribution limit reached ({DAILY_CONTRIBUTION_CAP}/24h). Please try again tomorrow.",
        )


def _verify_callback_token(token: str, expected: str) -> None:
    """Reject any callback that doesn't present the configured path secret.

    A plain public route with no verification means the only thing
    standing between an attacker and a forged "payment succeeded" event is
    knowledge of a contribution's reference — and that reference is
    returned to the payer in the 201 response, so it's never actually
    secret (see PAY-01). 404 rather than 401/403: an unauthenticated
    scanner gets no signal that a callback endpoint exists here at all.
    """
    if not expected or not hmac.compare_digest(token, expected):
        raise HTTPException(status_code=404)


def _settle_from_verified_status(
    db: Session, contribution: Contribution, verified: dict, receipt: str | None,
) -> None:
    """Credit or fail a contribution from an authenticated provider status
    check — never from the callback body itself, which is unauthenticated
    and forgeable. The amount credited is always `contribution.amount`
    (what we initiated the push for), never a value read from the callback
    body (see PAY-01, FIN-01).

    UNKNOWN changes nothing: the contribution stays PENDING and the
    reconciliation sweep asks the provider again. Treating "no answer" as
    FAILED used to drop paid contributions out of reconciliation for good.
    """
    if contribution.status not in (ContributionStatus.PENDING, ContributionStatus.FAILED):
        return  # already settled (SUCCESS) or withdrawn (CANCELLED)

    outcome = verified["outcome"]
    log_fields = dict(provider=contribution.provider.value, reference=contribution.reference)

    if outcome is ProviderOutcome.SUCCESS:
        # Ledger-backed, atomic and idempotent — see FIN-02.
        applied = ledger_service.credit_contribution(db, contribution, receipt, datetime.now(timezone.utc))
        log.info("payment.settled", outcome="success" if applied else "already_credited", **log_fields)
    elif outcome is ProviderOutcome.FAILED:
        if ledger_service.fail_contribution(db, contribution, verified.get("reason") or "Provider reported failure"):
            log.info("payment.settled", outcome="failed", reason=verified.get("reason"), **log_fields)
    else:
        log.info("payment.unresolved", reason=verified.get("reason"), **log_fields)


@router.post("/contributions/mpesa", response_model=ContributionResponse, status_code=202)
async def contribute_mpesa(
    payload: MpesaContributeRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    check_rate_limit("payment:initiate", str(current_user.id))
    project = _get_active_project(payload.project_id, db)
    _assert_chama_member(project, current_user, db)
    _assert_under_daily_cap(current_user, db)
    reference = _generate_reference("MPESA")

    # The handler does one thing: commit the contribution and an outbox
    # row in a single transaction, then return. A background worker drains
    # the outbox and performs the actual STK push (see PAY-03) — this
    # means a process death between "contribution recorded" and "push
    # sent" can no longer strand the contribution PENDING forever with no
    # prompt ever having been sent, and a slow Daraja call never blocks
    # this request for up to 15 seconds.
    contribution = Contribution(
        project_id=project.id,
        user_id=current_user.id,
        amount=payload.amount,
        provider=PaymentProvider.MPESA,
        phone=payload.phone,
        reference=reference,
        status=ContributionStatus.PENDING,
    )
    db.add(contribution)
    db.flush()
    db.add(OutboxMessage(
        topic="payment.initiate.mpesa",
        payload=json.dumps({"contribution_id": str(contribution.id)}),
    ))
    db.commit()
    db.refresh(contribution)
    log.info("payment.initiated", provider="mpesa", reference=reference)

    return ContributionResponse.model_validate(contribution)


@router.post("/contributions/airtel", response_model=ContributionResponse, status_code=202)
async def contribute_airtel(
    payload: AirtelContributeRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    check_rate_limit("payment:initiate", str(current_user.id))
    project = _get_active_project(payload.project_id, db)
    _assert_chama_member(project, current_user, db)
    _assert_under_daily_cap(current_user, db)
    reference = _generate_reference("AIRTEL")

    contribution = Contribution(
        project_id=project.id,
        user_id=current_user.id,
        amount=payload.amount,
        provider=PaymentProvider.AIRTEL,
        phone=payload.phone,
        reference=reference,
        status=ContributionStatus.PENDING,
    )
    db.add(contribution)
    db.flush()
    db.add(OutboxMessage(
        topic="payment.initiate.airtel",
        payload=json.dumps({"contribution_id": str(contribution.id)}),
    ))
    db.commit()
    db.refresh(contribution)
    log.info("payment.initiated", provider="airtel", reference=reference)

    return ContributionResponse.model_validate(contribution)


@router.get("/contributions/status/{reference}", response_model=ContributionStatusResponse)
def contribution_status(
    reference: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    contribution = db.query(Contribution).filter(
        Contribution.reference == reference,
        Contribution.user_id == current_user.id,
    ).first()
    if not contribution:
        raise HTTPException(status_code=404, detail="Contribution not found")

    return ContributionStatusResponse(
        reference=contribution.reference,
        status=contribution.status,
        provider_reference=contribution.provider_reference,
        amount=contribution.amount,
        completed_at=contribution.completed_at,
    )


@router.get("/users/me/contributions", response_model=list[ContributionResponse])
def my_contributions(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
):
    contributions = (
        db.query(Contribution)
        .filter(Contribution.user_id == current_user.id)
        .order_by(Contribution.initiated_at.desc())
        .offset((page - 1) * page_size)
        .limit(page_size)
        .all()
    )
    return [ContributionResponse.model_validate(c) for c in contributions]


@router.post("/payments/mpesa/callback/{token}", include_in_schema=False)
async def mpesa_callback(token: str, request: Request, db: Session = Depends(get_db)):
    _verify_callback_token(token, settings.MPESA_CALLBACK_TOKEN)
    raw = await request.body()

    try:
        stk_callback = json.loads(raw or b"{}").get("Body", {}).get("stkCallback", {})
    except json.JSONDecodeError:
        stk_callback = {}
    checkout_request_id = stk_callback.get("CheckoutRequestID")

    # Persist the raw payload unconditionally, before any decision is made —
    # forensics first, logic second (see PAY-01).
    event = ProviderEvent(
        provider=PaymentProvider.MPESA,
        reference=checkout_request_id,
        raw_body=raw.decode("utf-8", errors="replace"),
    )
    db.add(event)

    if not checkout_request_id:
        event.rejection_reason = "missing_checkout_request_id"
        db.commit()
        return {"ResultCode": 0, "ResultDesc": "Accepted"}

    contribution = db.query(Contribution).filter(
        Contribution.checkout_request_id == checkout_request_id
    ).first()
    if not contribution:
        event.rejection_reason = "unknown_checkout_request_id"
        db.commit()
        return {"ResultCode": 0, "ResultDesc": "Accepted"}

    # The callback body is only ever a hint that *something* happened for
    # this CheckoutRequestID — Safaricom's own query endpoint, called with
    # our own credentials, is the only source of truth for whether it
    # actually succeeded.
    verified = await mpesa.query_stk_status(checkout_request_id)
    event.verified = verified["outcome"] is ProviderOutcome.SUCCESS
    if not event.verified:
        event.rejection_reason = (verified.get("reason") or verified["outcome"].value)[:100]

    # The receipt number is only ever used as a display/support-reference
    # value below, never to decide whether to credit anything — that
    # decision rests solely on `verified["outcome"]` above. A forged
    # receipt string here cannot cause a false credit.
    items = {
        item.get("Name"): item.get("Value")
        for item in stk_callback.get("CallbackMetadata", {}).get("Item", [])
    }
    receipt_hint = items.get("MpesaReceiptNumber")

    _settle_from_verified_status(db, contribution, verified, receipt=receipt_hint)
    db.commit()
    return {"ResultCode": 0, "ResultDesc": "Accepted"}


@router.post("/payments/airtel/callback/{token}", include_in_schema=False)
async def airtel_callback(token: str, request: Request, db: Session = Depends(get_db)):
    _verify_callback_token(token, settings.AIRTEL_CALLBACK_TOKEN)
    raw = await request.body()

    try:
        body = json.loads(raw or b"{}")
    except json.JSONDecodeError:
        body = {}
    reference = (body.get("transaction") or {}).get("id")

    event = ProviderEvent(
        provider=PaymentProvider.AIRTEL,
        reference=reference,
        raw_body=raw.decode("utf-8", errors="replace"),
    )
    db.add(event)

    if not reference:
        event.rejection_reason = "missing_reference"
        db.commit()
        return {"status": "ok"}

    contribution = db.query(Contribution).filter(Contribution.reference == reference).first()
    if not contribution:
        event.rejection_reason = "unknown_reference"
        db.commit()
        return {"status": "ok"}

    # As with M-Pesa: the callback body is a hint, never the source of
    # truth. Query Airtel directly for this reference's real status.
    verified = await airtel.query_transaction_status(reference)
    event.verified = verified["outcome"] is ProviderOutcome.SUCCESS
    if not event.verified:
        event.rejection_reason = (verified.get("reason") or verified["outcome"].value)[:100]

    _settle_from_verified_status(db, contribution, verified, verified.get("receipt"))
    db.commit()
    return {"status": "ok"}
