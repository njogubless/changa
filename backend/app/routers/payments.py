import secrets
from datetime import datetime, timedelta, timezone
from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.database import get_db
from app.core.security import get_current_user
from app.core.ratelimit import check_rate_limit
from app.core.observability import get_logger
from app.models.models import (
    User, Project, Contribution, ContributionStatus, PaymentProvider,
    ChamaMember,
)

DAILY_CONTRIBUTION_CAP = 20
from app.schemas.projects import (
    MpesaContributeRequest, AirtelContributeRequest,
    ContributionResponse, ContributionStatusResponse,
    MpesaCallbackRequest, AirtelCallbackRequest,
)
from app.services import mpesa, airtel

router = APIRouter(tags=["Payments"])
log = get_logger("changa.payments")


def _generate_reference(prefix: str) -> str:
    return f"{prefix}-{secrets.token_hex(4).upper()}"


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
    is unlimited spend, not just an inconvenience. See SEC-03."""
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


def _apply_callback_result(contribution: Contribution, result: dict) -> None:
    """Update contribution from a payment callback. Idempotent for success."""
    if contribution.status == ContributionStatus.SUCCESS:
        return

    if contribution.status not in (
        ContributionStatus.PENDING,
        ContributionStatus.FAILED,
    ):
        return

    if result["success"]:
        callback_amount = result.get("amount")
        if callback_amount is not None and abs(callback_amount - contribution.amount) > 0.01:
            contribution.status = ContributionStatus.FAILED
            contribution.failure_reason = "Callback amount mismatch"
            log.warning(
                "payment.settled",
                outcome="amount_mismatch",
                provider=contribution.provider.value,
                reference=contribution.reference,
            )
            return

        contribution.status = ContributionStatus.SUCCESS
        contribution.provider_reference = result.get("receipt")
        contribution.completed_at = datetime.now(timezone.utc)
        contribution.project.raised_amount += contribution.amount
        log.info(
            "payment.settled",
            outcome="success",
            provider=contribution.provider.value,
            reference=contribution.reference,
        )
    else:
        contribution.status = ContributionStatus.FAILED
        contribution.failure_reason = result.get("failure_reason")
        log.info(
            "payment.settled",
            outcome="failed",
            provider=contribution.provider.value,
            reference=contribution.reference,
            reason=contribution.failure_reason,
        )


@router.post("/contributions/mpesa", response_model=ContributionResponse, status_code=201)
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
    db.commit()
    db.refresh(contribution)
    log.info("payment.initiated", provider="mpesa", reference=reference)

    try:
        await mpesa.stk_push(
            phone=payload.phone,
            amount=payload.amount,
            reference=reference,
            description=f"Changa: {project.title[:20]}",
        )
    except Exception as e:
        contribution.status = ContributionStatus.FAILED
        contribution.failure_reason = "Payment provider error"
        db.commit()
        log.warning("payment.provider_error", provider="mpesa", reference=reference)
        raise HTTPException(status_code=502, detail="M-Pesa request failed. Please try again.")

    return ContributionResponse.model_validate(contribution)


@router.post("/contributions/airtel", response_model=ContributionResponse, status_code=201)
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
    db.commit()
    db.refresh(contribution)
    log.info("payment.initiated", provider="airtel", reference=reference)

    try:
        await airtel.initiate_payment(
            phone=payload.phone,
            amount=payload.amount,
            reference=reference,
        )
    except Exception as e:
        contribution.status = ContributionStatus.FAILED
        contribution.failure_reason = "Payment provider error"
        db.commit()
        log.warning("payment.provider_error", provider="airtel", reference=reference)
        raise HTTPException(status_code=502, detail="Airtel request failed. Please try again.")

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


@router.post("/payments/mpesa/callback")
async def mpesa_callback(payload: MpesaCallbackRequest, db: Session = Depends(get_db)):
    result = mpesa.parse_callback(payload.model_dump())

    stk_callback = payload.Body.get("stkCallback", {})
    items = {
        item["Name"]: item.get("Value")
        for item in stk_callback.get("CallbackMetadata", {}).get("Item", [])
    }
    reference = items.get("AccountReference") or stk_callback.get("CheckoutRequestID")

    if not reference:
        return {"ResultCode": 0, "ResultDesc": "Accepted"}

    contribution = db.query(Contribution).filter(Contribution.reference == reference).first()
    if not contribution:
        return {"ResultCode": 0, "ResultDesc": "Accepted"}

    _apply_callback_result(contribution, result)
    db.commit()
    return {"ResultCode": 0, "ResultDesc": "Accepted"}


@router.post("/payments/airtel/callback")
async def airtel_callback(payload: AirtelCallbackRequest, db: Session = Depends(get_db)):
    result = airtel.parse_callback(payload.model_dump())
    reference = payload.transaction.get("id") if payload.transaction else None

    if not reference:
        return {"status": "ok"}

    contribution = db.query(Contribution).filter(Contribution.reference == reference).first()
    if not contribution:
        return {"status": "ok"}

    _apply_callback_result(contribution, result)
    db.commit()
    return {"status": "ok"}
