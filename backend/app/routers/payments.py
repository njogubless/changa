import secrets
from datetime import datetime, timezone
from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.database import get_db
from app.core.security import get_current_user
from app.models.models import User, Project, Contribution, ContributionStatus, PaymentProvider
from app.schemas.projects import (
    MpesaContributeRequest, AirtelContributeRequest,
    ContributionResponse, ContributionStatusResponse,
    MpesaCallbackRequest, AirtelCallbackRequest,
)
from app.services import mpesa, airtel

router = APIRouter(tags=["Payments"])


def _generate_reference(prefix: str) -> str:
    return f"{prefix}-{secrets.token_hex(4).upper()}"


def _get_active_project(project_id: UUID, db: Session) -> Project:
    project = db.query(Project).filter(Project.id == project_id).first()
    if not project:
        raise HTTPException(status_code=404, detail="Project not found")
    if project.status != "active":
        raise HTTPException(status_code=400, detail="Project is not accepting contributions")
    return project


# ── M-Pesa STK Push ────────────────────────────────────────────────────────────

@router.post("/contributions/mpesa", response_model=ContributionResponse, status_code=201)
async def contribute_mpesa(
    payload: MpesaContributeRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    project = _get_active_project(payload.project_id, db)
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

    try:
        await mpesa.stk_push(
            phone=payload.phone,
            amount=payload.amount,
            reference=reference,
            description=f"Changa: {project.title[:20]}",
        )
    except Exception as e:
        contribution.status = ContributionStatus.FAILED
        contribution.failure_reason = str(e)
        db.commit()
        raise HTTPException(status_code=502, detail=f"M-Pesa request failed: {str(e)}")

    return ContributionResponse.model_validate(contribution)


# ── Airtel Money ───────────────────────────────────────────────────────────────

@router.post("/contributions/airtel", response_model=ContributionResponse, status_code=201)
async def contribute_airtel(
    payload: AirtelContributeRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    project = _get_active_project(payload.project_id, db)
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

    try:
        await airtel.initiate_payment(
            phone=payload.phone,
            amount=payload.amount,
            reference=reference,
        )
    except Exception as e:
        contribution.status = ContributionStatus.FAILED
        contribution.failure_reason = str(e)
        db.commit()
        raise HTTPException(status_code=502, detail=f"Airtel request failed: {str(e)}")

    return ContributionResponse.model_validate(contribution)


# ── Status polling (Flutter polls every 3 seconds) ────────────────────────────

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


# ── My contribution history ────────────────────────────────────────────────────

@router.get("/users/me/contributions", response_model=list[ContributionResponse])
def my_contributions(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return [
        ContributionResponse.model_validate(c)
        for c in sorted(current_user.contributions, key=lambda x: x.initiated_at, reverse=True)
    ]


# ── M-Pesa Callback (called by Safaricom — no auth) ───────────────────────────

@router.post("/payments/mpesa/callback")
async def mpesa_callback(payload: MpesaCallbackRequest, db: Session = Depends(get_db)):
    result = mpesa.parse_callback(payload.model_dump())

    # Find contribution by AccountReference embedded in callback
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

    if result["success"]:
        contribution.status = ContributionStatus.SUCCESS
        contribution.provider_reference = result.get("receipt")
        contribution.completed_at = datetime.now(timezone.utc)
        contribution.project.raised_amount += contribution.amount
    else:
        contribution.status = ContributionStatus.FAILED
        contribution.failure_reason = result.get("failure_reason")

    db.commit()
    return {"ResultCode": 0, "ResultDesc": "Accepted"}


# ── Airtel Callback (called by Airtel — no auth) ──────────────────────────────

@router.post("/payments/airtel/callback")
async def airtel_callback(payload: AirtelCallbackRequest, db: Session = Depends(get_db)):
    result = airtel.parse_callback(payload.model_dump())
    reference = payload.transaction.get("id") if payload.transaction else None

    if not reference:
        return {"status": "ok"}

    contribution = db.query(Contribution).filter(Contribution.reference == reference).first()
    if not contribution:
        return {"status": "ok"}

    if result["success"]:
        contribution.status = ContributionStatus.SUCCESS
        contribution.provider_reference = result.get("receipt")
        contribution.completed_at = datetime.now(timezone.utc)
        contribution.project.raised_amount += contribution.amount
    else:
        contribution.status = ContributionStatus.FAILED
        contribution.failure_reason = result.get("failure_reason")

    db.commit()
    return {"status": "ok"}
