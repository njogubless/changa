"""Append-only audit trail. See REG-01 in docs/Changa_Engineering_audit.md.

Before this, state changes were in-place mutations with no record of
actor, time or previous value — update_project and update_chama loop
setattr over the payload, remove_member hard-deletes the row,
regenerate_invite_code overwrites in place. Nothing could answer "who
changed this project's target" or "who removed this member." Rows here
are written exclusively by the before_flush/after_flush hooks in
app/core/audit.py, never by route handlers directly, so coverage doesn't
depend on a developer remembering to log a change.

Production hardening this doesn't do yet: REVOKE UPDATE, DELETE ON
audit_events FROM the application's database role, so not even a bug (or
a compromised app server) can rewrite history. That's a deploy-time
grant change, not a model change, and needs to happen outside this repo
before going live.
"""
from sqlalchemy import BigInteger, Column, DateTime, ForeignKey, Index, Integer, JSON, String, func
from sqlalchemy.dialects.postgresql import JSONB, UUID

from app.database import Base

# Generic JSON, upgraded to native JSONB on Postgres. Plain postgresql.JSONB
# can't be compiled against the SQLite engine the test suite substitutes in
# (see TEST-01) — this pattern is SQLAlchemy's documented way to get real
# JSONB in production without breaking portability.
_JSONVariant = JSON().with_variant(JSONB, "postgresql")

# BigInteger on Postgres (BIGSERIAL — this table only grows), but SQLite
# only treats a column as an autoincrementing rowid alias when it's
# declared as exactly "INTEGER PRIMARY KEY" — BIGINT doesn't qualify, so
# under the SQLite test suite every insert failed NOT NULL on id with no
# autoincrement having fired. Same with_variant pattern as the JSON
# columns above; production keeps the real BIGSERIAL.
_IdVariant = BigInteger().with_variant(Integer, "sqlite")


class AuditEvent(Base):
    __tablename__ = "audit_events"

    id          = Column(_IdVariant, primary_key=True, autoincrement=True)
    occurred_at = Column(DateTime(timezone=True), nullable=False, server_default=func.now())
    actor_id    = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=True)
    # Plain string, not postgresql.INET, for the same SQLite-portability
    # reason as the JSON columns above.
    actor_ip    = Column(String(45), nullable=True)
    request_id  = Column(String(36), nullable=True)
    action      = Column(String(64), nullable=False)
    entity_type = Column(String(40), nullable=False)
    entity_id   = Column(UUID(as_uuid=True), nullable=False)
    before      = Column(_JSONVariant, nullable=True)
    after       = Column(_JSONVariant, nullable=True)

    __table_args__ = (
        Index("ix_audit_entity", "entity_type", "entity_id", "occurred_at"),
        Index("ix_audit_actor", "actor_id", "occurred_at"),
    )
