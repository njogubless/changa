import uuid
import secrets
from datetime import datetime, timezone
from sqlalchemy import (
    Column, String, Boolean, DateTime,
    Float, Text, ForeignKey, Enum as SAEnum
)
from sqlalchemy.orm import relationship
from sqlalchemy.dialects.postgresql import UUID
import enum

from app.database import Base


def utcnow():
    return datetime.now(timezone.utc)


def generate_invite_code() -> str:
    """Generate a unique 8-char invite code e.g. CHNG-4X9K"""
    return f"CHNG-{secrets.token_hex(2).upper()}"


# ── Enums ──────────────────────────────────────────────────────────────────────

class ChamaMemberRole(str, enum.Enum):
    OWNER = "owner"
    ADMIN = "admin"
    MEMBER = "member"


class ProjectStatus(str, enum.Enum):
    ACTIVE = "active"
    COMPLETED = "completed"
    CANCELLED = "cancelled"
    PAUSED = "paused"


class PaymentAccountType(str, enum.Enum):
    PAYBILL = "paybill"
    TILL = "till"
    POCHI = "pochi"


class ContributionStatus(str, enum.Enum):
    PENDING = "pending"
    SUCCESS = "success"
    FAILED = "failed"
    CANCELLED = "cancelled"


class PaymentProvider(str, enum.Enum):
    MPESA = "mpesa"
    AIRTEL = "airtel"


# ── Models ─────────────────────────────────────────────────────────────────────

class User(Base):
    __tablename__ = "users"

    id              = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4, index=True)
    email           = Column(String(255), unique=True, index=True, nullable=False)
    phone           = Column(String(20), unique=True, index=True, nullable=False)
    full_name       = Column(String(255), nullable=False)
    hashed_password = Column(String(255), nullable=False)
    avatar_url      = Column(String(500), nullable=True)
    is_active       = Column(Boolean, default=True)
    is_verified     = Column(Boolean, default=False)
    created_at      = Column(DateTime(timezone=True), default=utcnow)
    updated_at      = Column(DateTime(timezone=True), default=utcnow, onupdate=utcnow)

    # Relationships
    owned_chamas    = relationship("Chama", back_populates="owner", foreign_keys="Chama.owner_id")
    chama_memberships = relationship("ChamaMember", back_populates="user", foreign_keys="ChamaMember.user_id")
    owned_projects  = relationship("Project", back_populates="owner", foreign_keys="Project.owner_id")
    contributions   = relationship("Contribution", back_populates="user")
    refresh_tokens  = relationship("RefreshToken", back_populates="user", cascade="all, delete-orphan")


class Chama(Base):
    __tablename__ = "chamas"

    id           = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4, index=True)
    owner_id     = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False, index=True)
    name         = Column(String(255), nullable=False)
    description  = Column(Text, nullable=True)
    avatar_color = Column(String(7), default="#1B4332")   # hex — shown as chama icon bg
    invite_code  = Column(String(10), unique=True, nullable=False, default=generate_invite_code)
    is_active    = Column(Boolean, default=True)
    created_at   = Column(DateTime(timezone=True), default=utcnow)
    updated_at   = Column(DateTime(timezone=True), default=utcnow, onupdate=utcnow)

    # Relationships
    owner    = relationship("User", back_populates="owned_chamas", foreign_keys=[owner_id])
    members  = relationship("ChamaMember", back_populates="chama", cascade="all, delete-orphan")
    projects = relationship("Project", back_populates="chama", cascade="all, delete-orphan")

    @property
    def member_count(self) -> int:
        return len(self.members)

    @property
    def active_project_count(self) -> int:
        return sum(1 for p in self.projects if p.status == ProjectStatus.ACTIVE)


class ChamaMember(Base):
    __tablename__ = "chama_members"

    id         = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    chama_id   = Column(UUID(as_uuid=True), ForeignKey("chamas.id"), nullable=False, index=True)
    user_id    = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False, index=True)
    role       = Column(SAEnum(ChamaMemberRole), default=ChamaMemberRole.MEMBER)
    invited_by = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=True)
    joined_at  = Column(DateTime(timezone=True), default=utcnow)

    # Relationships
    chama = relationship("Chama", back_populates="members")
    user  = relationship("User", back_populates="chama_memberships", foreign_keys=[user_id])


class Project(Base):
    __tablename__ = "projects"

    id             = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4, index=True)
    chama_id       = Column(UUID(as_uuid=True), ForeignKey("chamas.id"), nullable=False, index=True)
    owner_id       = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False, index=True)
    title          = Column(String(255), nullable=False)
    description    = Column(Text, nullable=True)
    cover_image_url = Column(String(500), nullable=True)
    target_amount  = Column(Float, nullable=False)
    raised_amount  = Column(Float, default=0.0)
    currency       = Column(String(3), default="KES")
    status         = Column(SAEnum(ProjectStatus), default=ProjectStatus.ACTIVE)
    is_anonymous   = Column(Boolean, default=False)
    deadline       = Column(DateTime(timezone=True), nullable=True)

    # Payment account — the number contributors send money to
    payment_type      = Column(SAEnum(PaymentAccountType), nullable=False)
    payment_number    = Column(String(20), nullable=False)   # till/paybill/phone number
    payment_name      = Column(String(255), nullable=True)   # verified account name from Daraja
    account_reference = Column(String(100), nullable=True)   # for paybill account number

    created_at = Column(DateTime(timezone=True), default=utcnow)
    updated_at = Column(DateTime(timezone=True), default=utcnow, onupdate=utcnow)

    # Relationships
    chama         = relationship("Chama", back_populates="projects")
    owner         = relationship("User", back_populates="owned_projects", foreign_keys=[owner_id])
    contributions = relationship("Contribution", back_populates="project")

    # Computed properties
    @property
    def percentage_funded(self) -> float:
        if self.target_amount == 0:
            return 0.0
        return round((self.raised_amount / self.target_amount) * 100, 2)

    @property
    def deficit(self) -> float:
        return max(0.0, self.target_amount - self.raised_amount)

    @property
    def is_funded(self) -> bool:
        return self.raised_amount >= self.target_amount

    @property
    def contributor_count(self) -> int:
        return len(set(
            c.user_id for c in self.contributions
            if c.status == ContributionStatus.SUCCESS
        ))


class Contribution(Base):
    __tablename__ = "contributions"

    id                 = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4, index=True)
    project_id         = Column(UUID(as_uuid=True), ForeignKey("projects.id"), nullable=False, index=True)
    user_id            = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False, index=True)
    amount             = Column(Float, nullable=False)
    currency           = Column(String(3), default="KES")
    provider           = Column(SAEnum(PaymentProvider), nullable=False)
    phone              = Column(String(20), nullable=False)
    reference          = Column(String(100), unique=True, index=True, nullable=False)
    provider_reference = Column(String(100), nullable=True)
    status             = Column(SAEnum(ContributionStatus), default=ContributionStatus.PENDING)
    failure_reason     = Column(Text, nullable=True)
    initiated_at       = Column(DateTime(timezone=True), default=utcnow)
    completed_at       = Column(DateTime(timezone=True), nullable=True)

    # Relationships
    project = relationship("Project", back_populates="contributions")
    user    = relationship("User", back_populates="contributions")


class RefreshToken(Base):
    __tablename__ = "refresh_tokens"

    id         = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id    = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False, index=True)
    token      = Column(String(500), unique=True, nullable=False)
    is_revoked = Column(Boolean, default=False)
    created_at = Column(DateTime(timezone=True), default=utcnow)
    expires_at = Column(DateTime(timezone=True), nullable=False)

    # Relationships
    user = relationship("User", back_populates="refresh_tokens")