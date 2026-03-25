from pydantic import BaseModel, field_validator
from typing import Optional, List
from uuid import UUID
from datetime import datetime
from app.models.models import ProjectStatus, ProjectVisibility, ContributionStatus, PaymentProvider


# ── Projects ───────────────────────────────────────────────────────────────────

class ProjectCreateRequest(BaseModel):
    title: str
    description: Optional[str] = None
    target_amount: float
    visibility: ProjectVisibility = ProjectVisibility.PUBLIC
    is_anonymous: bool = False
    deadline: Optional[datetime] = None
    cover_image_url: Optional[str] = None

    @field_validator("target_amount")
    @classmethod
    def validate_amount(cls, v: float) -> float:
        if v < 100:
            raise ValueError("Target amount must be at least KES 100")
        return v

    @field_validator("title")
    @classmethod
    def validate_title(cls, v: str) -> str:
        if len(v.strip()) < 3:
            raise ValueError("Title must be at least 3 characters")
        return v.strip()


class ProjectUpdateRequest(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    target_amount: Optional[float] = None
    visibility: Optional[ProjectVisibility] = None
    is_anonymous: Optional[bool] = None
    deadline: Optional[datetime] = None
    cover_image_url: Optional[str] = None
    status: Optional[ProjectStatus] = None


class ProjectResponse(BaseModel):
    id: UUID
    owner_id: UUID
    title: str
    description: Optional[str]
    cover_image_url: Optional[str]
    target_amount: float
    raised_amount: float
    currency: str
    visibility: ProjectVisibility
    status: ProjectStatus
    is_anonymous: bool
    deadline: Optional[datetime]
    percentage_funded: float
    deficit: float
    is_funded: bool
    contributor_count: int
    created_at: datetime

    model_config = {"from_attributes": True}


class ProjectListResponse(BaseModel):
    items: List[ProjectResponse]
    total: int
    page: int
    pages: int


class InviteMemberRequest(BaseModel):
    email: Optional[str] = None
    phone: Optional[str] = None


class TeamCreateRequest(BaseModel):
    name: str
    description: Optional[str] = None


class TeamResponse(BaseModel):
    id: UUID
    project_id: UUID
    name: str
    description: Optional[str]
    created_at: datetime
    total_raised: float

    model_config = {"from_attributes": True}


# ── Payments ───────────────────────────────────────────────────────────────────

class MpesaContributeRequest(BaseModel):
    project_id: UUID
    amount: float
    phone: str

    @field_validator("amount")
    @classmethod
    def validate_amount(cls, v: float) -> float:
        if v < 1:
            raise ValueError("Amount must be at least KES 1")
        if v > 300000:
            raise ValueError("Amount cannot exceed KES 300,000 per transaction")
        return v

    @field_validator("phone")
    @classmethod
    def validate_phone(cls, v: str) -> str:
        import re
        cleaned = re.sub(r"\s+", "", v)
        if not re.match(r"^254[17]\d{8}$", cleaned):
            raise ValueError("Phone must be a valid Kenyan number: 254XXXXXXXXX")
        return cleaned


class AirtelContributeRequest(BaseModel):
    project_id: UUID
    amount: float
    phone: str

    @field_validator("amount")
    @classmethod
    def validate_amount(cls, v: float) -> float:
        if v < 1:
            raise ValueError("Amount must be at least KES 1")
        return v


class ContributionResponse(BaseModel):
    id: UUID
    project_id: UUID
    amount: float
    currency: str
    provider: PaymentProvider
    phone: str
    reference: str
    provider_reference: Optional[str]
    status: ContributionStatus
    failure_reason: Optional[str]
    initiated_at: datetime
    completed_at: Optional[datetime]

    model_config = {"from_attributes": True}


class ContributionStatusResponse(BaseModel):
    reference: str
    status: ContributionStatus
    provider_reference: Optional[str]
    amount: float
    completed_at: Optional[datetime]


class MpesaCallbackRequest(BaseModel):
    Body: dict


class AirtelCallbackRequest(BaseModel):
    transaction: Optional[dict] = None
    status: Optional[str] = None
