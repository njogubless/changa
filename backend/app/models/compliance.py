"""KYC scaffolding and consent evidence. See REG-01 in
docs/Changa_Engineering_audit.md.
"""
import enum
import uuid

from sqlalchemy import Boolean, Column, Date, DateTime, Enum as SAEnum, ForeignKey, String, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship

from app.database import Base
from app.models.models import utcnow


class KycTier(str, enum.Enum):
    TIER0 = "tier0"
    TIER1 = "tier1"
    TIER2 = "tier2"


class IdDocumentType(str, enum.Enum):
    NATIONAL_ID = "national_id"
    PASSPORT = "passport"
    ALIEN_ID = "alien_id"


class ScreeningStatus(str, enum.Enum):
    PENDING = "pending"
    CLEARED = "cleared"
    FLAGGED = "flagged"


class KycProfile(Base):
    """Scaffolding only, deliberately not enforced.

    Every user gets a TIER0 row at registration (see register() in
    routers/auth.py), but there is no identity-verification flow yet to
    move anyone off it, and nothing in the payment path reads these
    limits today. Shipping a hard contribution cap with no way for a
    user to ever raise it is a product decision, not just a schema
    change — deferred on purpose rather than silently enforced. The
    table exists now so the audit trail (AuditEvent) and the eventual
    verification flow have somewhere to write to, and so this doesn't
    need a second migration later just to add the column that gates
    real money movement.
    """
    __tablename__ = "kyc_profiles"

    user_id          = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), primary_key=True)
    tier             = Column(SAEnum(KycTier), nullable=False, default=KycTier.TIER0)
    id_type          = Column(SAEnum(IdDocumentType), nullable=True)
    id_number_hash   = Column(String(64), nullable=True, index=True)  # hashed, never stored raw
    date_of_birth    = Column(Date, nullable=True)
    verified_at      = Column(DateTime(timezone=True), nullable=True)
    verified_by      = Column(String(40), nullable=True)  # provider name, once one exists
    screening_status = Column(SAEnum(ScreeningStatus), nullable=False, default=ScreeningStatus.PENDING)
    created_at       = Column(DateTime(timezone=True), default=utcnow)

    user = relationship("User")


class ConsentRecord(Base):
    """Evidence, not a flag. Before this the mobile app gated the register
    button on a checkbox (_hasConsented in register_screen.dart) but never
    sent it anywhere — the server had no record that consent was ever
    given, which the audit calls out as arguably worse than not asking at
    all, since the UI implies it's tracked. One row per grant; never
    updated or deleted, so a policy re-acceptance is a new row, not an
    overwrite.
    """
    __tablename__ = "consent_records"

    id             = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id        = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    policy         = Column(String(40), nullable=False)   # terms_and_privacy
    policy_version = Column(String(20), nullable=False)
    granted        = Column(Boolean, nullable=False)
    ip             = Column(String(45), nullable=True)
    user_agent     = Column(String(255), nullable=True)
    recorded_at    = Column(DateTime(timezone=True), nullable=False, server_default=func.now())

    user = relationship("User")
