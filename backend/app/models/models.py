import uuid
import secrets
from decimal import Decimal
from datetime import datetime, timezone
from sqlalchemy import (
    Column, String, Boolean, DateTime,
    Text, ForeignKey, Integer,
    Enum as SAEnum, UniqueConstraint,
    CheckConstraint, Index,
)
from sqlalchemy.orm import relationship
from sqlalchemy.dialects.postgresql import UUID
import enum

from app.database import Base
from app.core.types import MoneyColumn, ZERO


def utcnow():
    return datetime.now(timezone.utc)


def generate_invite_code() -> str:
    return f"CHNG-{secrets.token_hex(4).upper()}"




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


class LedgerDirection(str, enum.Enum):
    CREDIT = "credit"
    REVERSAL = "reversal"


class BudgetType(str, enum.Enum):
    PERSONAL = "personal"
    EVENT = "event"
    CHAMA = "chama"


class BudgetCategoryType(str, enum.Enum):
    # Personal
    FOOD = "food"
    TRANSPORT = "transport"
    RENT = "rent"
    UTILITIES = "utilities"
    HEALTHCARE = "healthcare"
    EDUCATION = "education"
    ENTERTAINMENT = "entertainment"
    CLOTHING = "clothing"
    SAVINGS = "savings"
    # Event
    VENUE = "venue"
    CATERING = "catering"
    DECORATION = "decoration"
    PHOTOGRAPHY = "photography"
    MUSIC = "music"
    GIFTS = "gifts"
    # Chama
    CONTRIBUTION = "contribution"
    # Other
    OTHER = "other"




class User(Base):
    __tablename__ = "users"

    id              = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4, index=True)
    email           = Column(String(255), unique=True, index=True, nullable=False)
    phone           = Column(String(20), unique=True, index=True, nullable=False)
    full_name       = Column(String(255), nullable=False)
    hashed_password = Column(String(255), nullable=False)
    avatar_url      = Column(String(500), nullable=True)
    is_active       = Column(Boolean, nullable=False, default=True)
    is_verified     = Column(Boolean, nullable=False, default=False)
    created_at      = Column(DateTime(timezone=True), default=utcnow)
    updated_at      = Column(DateTime(timezone=True), default=utcnow, onupdate=utcnow)

    # Relationships
    owned_chamas      = relationship("Chama", back_populates="owner", foreign_keys="Chama.owner_id")
    chama_memberships = relationship("ChamaMember", back_populates="user", foreign_keys="ChamaMember.user_id")
    owned_projects    = relationship("Project", back_populates="owner", foreign_keys="Project.owner_id")
    contributions     = relationship("Contribution", back_populates="user")
    refresh_tokens    = relationship("RefreshToken", back_populates="user", cascade="all, delete-orphan")
    budgets           = relationship("Budget", back_populates="user", cascade="all, delete-orphan")


class RefreshToken(Base):
    __tablename__ = "refresh_tokens"

    id         = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id    = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    token      = Column(String(500), unique=True, nullable=False)
    is_revoked = Column(Boolean, nullable=False, default=False)
    created_at = Column(DateTime(timezone=True), default=utcnow)
    expires_at = Column(DateTime(timezone=True), nullable=False)

    user = relationship("User", back_populates="refresh_tokens")


class Chama(Base):
    __tablename__ = "chamas"

    id           = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4, index=True)
    owner_id     = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False, index=True)
    name         = Column(String(255), nullable=False)
    description  = Column(Text, nullable=True)
    avatar_color = Column(String(7), default="#1B4332")
    invite_code  = Column(String(16), unique=True, nullable=False, default=generate_invite_code)
    is_active    = Column(Boolean, nullable=False, default=True)
    created_at   = Column(DateTime(timezone=True), default=utcnow)
    updated_at   = Column(DateTime(timezone=True), default=utcnow, onupdate=utcnow)

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
    __table_args__ = (
        UniqueConstraint("chama_id", "user_id", name="uq_chama_member"),
    )

    id         = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    chama_id   = Column(UUID(as_uuid=True), ForeignKey("chamas.id", ondelete="CASCADE"), nullable=False, index=True)
    user_id    = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False, index=True)
    role       = Column(SAEnum(ChamaMemberRole), nullable=False, default=ChamaMemberRole.MEMBER)
    invited_by = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=True)
    joined_at  = Column(DateTime(timezone=True), default=utcnow)

    chama = relationship("Chama", back_populates="members")
    user  = relationship("User", back_populates="chama_memberships", foreign_keys=[user_id])




class Project(Base):
    __tablename__ = "projects"

    id              = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4, index=True)
    chama_id        = Column(UUID(as_uuid=True), ForeignKey("chamas.id", ondelete="CASCADE"), nullable=False, index=True)
    owner_id        = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False, index=True)
    title           = Column(String(255), nullable=False)
    description     = Column(Text, nullable=True)
    cover_image_url = Column(String(500), nullable=True)
    target_amount   = Column(MoneyColumn, nullable=False)
    raised_amount   = Column(MoneyColumn, nullable=False, default=ZERO)
    currency        = Column(String(3), nullable=False, default="KES")
    status          = Column(SAEnum(ProjectStatus), nullable=False, default=ProjectStatus.ACTIVE)
    is_anonymous    = Column(Boolean, nullable=False, default=False)
    deadline        = Column(DateTime(timezone=True), nullable=True)
    payment_type    = Column(SAEnum(PaymentAccountType), nullable=False)
    payment_number  = Column(String(20), nullable=False)
    payment_name    = Column(String(255), nullable=True)
    account_reference = Column(String(100), nullable=True)
    created_at      = Column(DateTime(timezone=True), default=utcnow)
    updated_at      = Column(DateTime(timezone=True), default=utcnow, onupdate=utcnow)

    chama          = relationship("Chama", back_populates="projects")
    owner          = relationship("User", back_populates="owned_projects", foreign_keys=[owner_id])
    contributions  = relationship("Contribution", back_populates="project")
    ledger_entries = relationship("LedgerEntry", back_populates="project", order_by="LedgerEntry.created_at")

    @property
    def percentage_funded(self) -> float:
        if self.target_amount == 0:
            return 0.0
        # A display ratio, not a stored monetary value — float here is fine.
        return round(float(self.raised_amount / self.target_amount) * 100, 2)

    @property
    def deficit(self) -> Decimal:
        return max(ZERO, self.target_amount - self.raised_amount)

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
    __table_args__ = (
        # One M-Pesa/Airtel receipt can only ever settle one contribution.
        # NULLs (a contribution with no receipt yet) don't collide with
        # each other under Postgres unique-constraint semantics, so this
        # only bites once a receipt is actually recorded twice — which
        # should be structurally impossible, and this constraint is what
        # makes it actually impossible rather than merely unlikely.
        UniqueConstraint("provider", "provider_reference", name="uq_contribution_provider_receipt"),
        CheckConstraint("amount > 0", name="ck_contribution_amount_positive"),
        Index("ix_contributions_project_status", "project_id", "status"),
    )

    id                 = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4, index=True)
    project_id         = Column(UUID(as_uuid=True), ForeignKey("projects.id"), nullable=False, index=True)
    user_id            = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False, index=True)
    amount             = Column(MoneyColumn, nullable=False)
    currency           = Column(String(3), nullable=False, default="KES")
    provider           = Column(SAEnum(PaymentProvider), nullable=False)
    phone              = Column(String(20), nullable=False)
    reference          = Column(String(100), unique=True, index=True, nullable=False)
    provider_reference = Column(String(100), nullable=True)
    # Daraja's CheckoutRequestID — the handle used to query M-Pesa
    # server-to-server for the authoritative status of this push. Never
    # exposed in ContributionResponse: unlike `reference`, this value must
    # not be knowable to the payer, or it becomes another forgeable lookup
    # key for the callback (see PAY-01).
    checkout_request_id = Column(String(100), nullable=True, index=True)
    status             = Column(SAEnum(ContributionStatus), nullable=False, default=ContributionStatus.PENDING)
    failure_reason     = Column(Text, nullable=True)
    initiated_at       = Column(DateTime(timezone=True), default=utcnow)
    completed_at       = Column(DateTime(timezone=True), nullable=True)

    project = relationship("Project", back_populates="contributions")
    user    = relationship("User", back_populates="contributions")


class LedgerEntry(Base):
    """Append-only record of every change to a project's raised total.

    This is the single source of truth for how much a project has raised —
    `Project.raised_amount` is a projection maintained atomically alongside
    it, never the authority itself. Nothing ever UPDATEs or DELETEs a row
    here; a correction is a REVERSAL row, not an edit. See FIN-02 in
    docs/Changa_Engineering_audit.md.
    """
    __tablename__ = "ledger_entries"

    id              = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4, index=True)
    project_id      = Column(UUID(as_uuid=True), ForeignKey("projects.id"), nullable=False, index=True)
    contribution_id = Column(UUID(as_uuid=True), ForeignKey("contributions.id"), nullable=False)
    direction       = Column(SAEnum(LedgerDirection), nullable=False)
    amount          = Column(MoneyColumn, nullable=False)
    currency        = Column(String(3), nullable=False, default="KES")
    reverses_id     = Column(UUID(as_uuid=True), ForeignKey("ledger_entries.id"), nullable=True)
    created_at      = Column(DateTime(timezone=True), nullable=False, default=utcnow)

    project      = relationship("Project", back_populates="ledger_entries")
    contribution = relationship("Contribution")

    __table_args__ = (
        # One ledger row per (contribution, direction) — the database
        # enforces single-crediting even if application logic calls the
        # credit path twice for the same contribution (a replayed or
        # duplicated provider callback).
        UniqueConstraint("contribution_id", "direction", name="uq_ledger_contribution_direction"),
        CheckConstraint("amount > 0", name="ck_ledger_amount_positive"),
        Index("ix_ledger_project_created", "project_id", "created_at"),
    )


class ProviderEvent(Base):
    """Every raw payment-provider callback, persisted before any logic runs.

    The callback body is unauthenticated and forgeable (see PAY-01) — it is
    treated purely as a signal to go verify with the provider, never as a
    source of truth. Persisting the raw body first, unconditionally, means
    a forged attempt is forensically visible even though it is never acted
    on.
    """
    __tablename__ = "provider_events"

    id                = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4, index=True)
    provider          = Column(SAEnum(PaymentProvider), nullable=False)
    reference         = Column(String(100), nullable=True, index=True)
    raw_body          = Column(Text, nullable=False)
    verified          = Column(Boolean, nullable=False, default=False)
    rejection_reason  = Column(String(100), nullable=True)
    received_at       = Column(DateTime(timezone=True), nullable=False, default=utcnow)



class Budget(Base):
    """Top-level budget — personal, event, or chama-linked."""
    __tablename__ = "budgets"

    id              = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4, index=True)
    user_id         = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    title           = Column(String(255), nullable=False)
    type            = Column(SAEnum(BudgetType), nullable=False, default=BudgetType.PERSONAL)
    total_income    = Column(MoneyColumn, nullable=False, default=ZERO)
    currency        = Column(String(3), nullable=False, default="KES")
    event_date      = Column(DateTime(timezone=True), nullable=True)

    
    linked_chama_id   = Column(UUID(as_uuid=True), ForeignKey("chamas.id"), nullable=True, index=True)
    linked_chama_name = Column(String(255), nullable=True)  

    
    linked_project_id   = Column(UUID(as_uuid=True), ForeignKey("projects.id"), nullable=True, index=True)
    linked_project_name = Column(String(255), nullable=True) 

    created_at = Column(DateTime(timezone=True), default=utcnow)
    updated_at = Column(DateTime(timezone=True), default=utcnow, onupdate=utcnow)

    # Relationships
    user       = relationship("User", back_populates="budgets")
    categories = relationship("BudgetCategory", back_populates="budget",
                              cascade="all, delete-orphan",
                              order_by="BudgetCategory.sort_order")

    @property
    def total_allocated(self) -> Decimal:
        return sum((c.allocated_amount for c in self.categories), ZERO)

    @property
    def total_spent(self) -> Decimal:
        return sum((c.spent_amount for c in self.categories), ZERO)

    @property
    def unallocated(self) -> Decimal:
        return self.total_income - self.total_allocated

    @property
    def overall_progress(self) -> float:
        if self.total_allocated == 0:
            return 0.0
        return round(float(self.total_spent / self.total_allocated), 4)


class BudgetCategory(Base):
    """A spending category within a budget (e.g. Food, Venue, Transport)."""
    __tablename__ = "budget_categories"

    id               = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4, index=True)
    budget_id        = Column(UUID(as_uuid=True), ForeignKey("budgets.id", ondelete="CASCADE"), nullable=False, index=True)
    category         = Column(SAEnum(BudgetCategoryType), nullable=False, default=BudgetCategoryType.OTHER)
    custom_label     = Column(String(255), nullable=True)   # override the default category name
    allocated_amount = Column(MoneyColumn, nullable=False, default=ZERO)
    spent_amount     = Column(MoneyColumn, nullable=False, default=ZERO)   # updated by expenses
    sort_order       = Column(Integer, nullable=False, default=0)
    created_at       = Column(DateTime(timezone=True), default=utcnow)

    
    budget   = relationship("Budget", back_populates="categories")
    expenses = relationship("BudgetExpense", back_populates="category",
                            cascade="all, delete-orphan",
                            order_by="BudgetExpense.date.desc()")

    @property
    def label(self) -> str:
        return self.custom_label or self.category.value.replace("_", " ").title()

    @property
    def remaining(self) -> Decimal:
        return self.allocated_amount - self.spent_amount

    @property
    def progress(self) -> float:
        if self.allocated_amount == 0:
            return 0.0
        return round(float(self.spent_amount / self.allocated_amount), 4)

    @property
    def is_over_budget(self) -> bool:
        return self.spent_amount > self.allocated_amount


class BudgetExpense(Base):
    """An actual expense recorded under a budget category."""
    __tablename__ = "budget_expenses"

    id          = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4, index=True)
    category_id = Column(UUID(as_uuid=True), ForeignKey("budget_categories.id", ondelete="CASCADE"), nullable=False, index=True)
    description = Column(String(500), nullable=False)
    amount      = Column(MoneyColumn, nullable=False)
    date        = Column(DateTime(timezone=True), nullable=False, default=utcnow)
    created_at  = Column(DateTime(timezone=True), default=utcnow)

    # Relationships
    category = relationship("BudgetCategory", back_populates="expenses")