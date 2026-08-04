"""Automatic append-only audit trail. See REG-01 in
docs/Changa_Engineering_audit.md.

Registered once as a SQLAlchemy Session event (import this module once
at process start — app/main.py does it — and it applies to every Session
built off sessionmaker, prod and test alike). Deliberately a session
hook rather than something each route handler calls: coverage doesn't
depend on a developer remembering to log a change, which is exactly how
update_project/update_chama's blind setattr loops ended up with zero
audit trail in the first place.

Single-phase before_flush, not before_flush+after_flush: SQLAlchemy
explicitly supports session.add()-ing new objects from inside
before_flush and having them swept into the same flush automatically,
but does *not* support calling session.flush() again from after_flush
("Session is already flushing"). The only reason to need after_flush at
all would be to read a newly created row's primary key, which normally
isn't populated until the INSERT executes — but every AUDITED model here
uses a UUID primary key with a client-side default (default=uuid.uuid4),
so this hook just generates that id itself, one flush early, when it's
still None. That's not a workaround; it's the same value the column
default would have produced, just computed a moment sooner.
"""
import uuid
from functools import lru_cache

from sqlalchemy import event, inspect
from sqlalchemy.orm import Session

from app.core.audit_context import get_actor_id, get_actor_ip, get_request_id
from app.models.audit import AuditEvent
from app.models.models import Budget, Chama, ChamaMember, Contribution, Project, User

AUDITED = {User, Chama, ChamaMember, Project, Contribution, Budget}

# Never write a password hash into the audit trail, even hashed.
REDACT_FIELDS = {"hashed_password"}


@lru_cache(maxsize=None)
def _column_keys(model: type) -> tuple[str, ...]:
    """Column-backed attribute names only — excludes relationships, so this
    never triggers a lazy-load or serializes a related object graph."""
    return tuple(attr.key for attr in inspect(model).column_attrs)


def _safe(value):
    if hasattr(value, "isoformat"):  # datetime, date
        return value.isoformat()
    if isinstance(value, (str, int, float, bool)) or value is None:
        return value
    return str(value)  # UUID, Decimal, Enum, anything else JSON can't hold


@event.listens_for(Session, "before_flush")
def capture_changes(session, flush_context, instances):
    events = []

    for obj in list(session.new):
        if type(obj) not in AUDITED:
            continue
        if obj.id is None:
            obj.id = uuid.uuid4()
        after = {
            k: _safe(getattr(obj, k, None))
            for k in _column_keys(type(obj))
            if k not in REDACT_FIELDS and k != "id"
        }
        events.append(AuditEvent(
            action=f"{obj.__tablename__}.created",
            entity_type=obj.__tablename__, entity_id=obj.id,
            before=None, after=after,
        ))

    for obj in list(session.dirty):
        if type(obj) not in AUDITED or not session.is_modified(obj):
            continue
        state = inspect(obj)
        before, after = {}, {}
        for key in _column_keys(type(obj)):
            if key in REDACT_FIELDS:
                continue
            hist = state.attrs[key].load_history()
            if hist.has_changes():
                before[key] = _safe(hist.deleted[0]) if hist.deleted else None
                after[key] = _safe(hist.added[0]) if hist.added else None
        if after:
            events.append(AuditEvent(
                action=f"{obj.__tablename__}.updated",
                entity_type=obj.__tablename__, entity_id=obj.id,
                before=before, after=after,
            ))

    for obj in list(session.deleted):
        if type(obj) not in AUDITED:
            continue
        before = {
            k: _safe(getattr(obj, k, None))
            for k in _column_keys(type(obj))
            if k not in REDACT_FIELDS
        }
        events.append(AuditEvent(
            action=f"{obj.__tablename__}.deleted",
            entity_type=obj.__tablename__, entity_id=obj.id,
            before=before, after=None,
        ))

    if not events:
        return

    actor_id = get_actor_id()
    actor_ip = get_actor_ip()
    request_id = get_request_id()
    for e in events:
        e.actor_id = actor_id
        e.actor_ip = actor_ip
        e.request_id = request_id
        session.add(e)
