from pydantic import BaseModel, field_validator
from typing import Optional, List
from uuid import UUID
from datetime import datetime
from app.models.models import ChamaMemberRole


# ── Chama ──────────────────────────────────────────────────────────────────────

class ChamaCreateRequest(BaseModel):
    name: str
    description: Optional[str] = None
    avatar_color: Optional[str] = "#1B4332"

    @field_validator("name")
    @classmethod
    def validate_name(cls, v: str) -> str:
        if len(v.strip()) < 3:
            raise ValueError("Chama name must be at least 3 characters")
        return v.strip()

    @field_validator("avatar_color")
    @classmethod
    def validate_color(cls, v: str) -> str:
        if v and not v.startswith("#"):
            raise ValueError("Avatar color must be a valid hex color e.g. #1B4332")
        return v


class ChamaUpdateRequest(BaseModel):
    name: Optional[str] = None
    description: Optional[str] = None
    avatar_color: Optional[str] = None


class JoinChamaRequest(BaseModel):
    invite_code: str

    @field_validator("invite_code")
    @classmethod
    def validate_code(cls, v: str) -> str:
        return v.strip().upper()


class ChamaMemberResponse(BaseModel):
    user_id: UUID
    full_name: str
    email: str
    role: ChamaMemberRole
    joined_at: datetime

    model_config = {"from_attributes": True}


class ChamaResponse(BaseModel):
    id: UUID
    owner_id: UUID
    name: str
    description: Optional[str]
    avatar_color: str
    invite_code: str
    is_active: bool
    member_count: int
    active_project_count: int
    created_at: datetime

    model_config = {"from_attributes": True}


class ChamaDetailResponse(ChamaResponse):
    """Extended response including members list — for chama detail screen."""
    members: List[ChamaMemberResponse] = []

    model_config = {"from_attributes": True}


class ChamaListResponse(BaseModel):
    items: List[ChamaResponse]
    total: int