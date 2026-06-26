

from pydantic import BaseModel, field_validator
from typing import Optional
from uuid import UUID
from datetime import datetime
import re


# ── Requests ───────────────────────────────────────────────────────────────────

class InviteByPhoneRequest(BaseModel):
    phone: str

    @field_validator("phone")
    @classmethod
    def validate_phone(cls, v: str) -> str:
        cleaned = re.sub(r"\s+", "", v)
        if not re.match(r"^254[17]\d{8}$", cleaned):
            raise ValueError("Phone must be a valid Kenyan number: 254XXXXXXXXX")
        return cleaned


class JoinByChamaCodeRequest(BaseModel):
    invite_code: str

    @field_validator("invite_code")
    @classmethod
    def validate_code(cls, v: str) -> str:
        code = v.strip().upper()
        if len(code) < 6:
            raise ValueError("Invite code is too short")
        return code


class InviteActionRequest(BaseModel):
    action: str  # "accept" | "decline"

    @field_validator("action")
    @classmethod
    def validate_action(cls, v: str) -> str:
        if v not in ("accept", "decline"):
            raise ValueError("Action must be 'accept' or 'decline'")
        return v


# ── Responses ──────────────────────────────────────────────────────────────────

class ChamaInviteResponse(BaseModel):
    id: UUID
    chama_id: UUID
    chama_name: str
    chama_description: Optional[str]
    invited_by_name: str
    method: str
    status: str
    created_at: datetime
    expires_at: datetime

    model_config = {"from_attributes": True}


class GeneratedCodeResponse(BaseModel):
    invite_code: str
    expires_at: datetime
    chama_id: UUID
    chama_name: str
