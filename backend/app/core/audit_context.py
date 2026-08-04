"""Per-request actor identity, readable from inside the SQLAlchemy
before_flush hook in app/core/audit.py, which has no access to the
current Request or the authenticated user otherwise.

Uses contextvars, the same mechanism structlog.contextvars already relies
on for request_id (see OBS-01) — but with one crucial difference in
*where* it gets set. FastAPI resolves each sync dependency (and the sync
route handler itself) via its own independent
anyio.to_thread.run_sync() call, and each of those does its own
contextvars.copy_context() from the ambient async context at the moment
it's invoked. Reads flow correctly — a copy always sees whatever was set
in the ambient context *before* the copy was taken. But writes made
*inside* one of those copied contexts (e.g. calling set_actor_id() from
inside the get_current_user dependency, which is its own separate
threadpool dispatch) are invisible everywhere else, including the route
handler's own separate threadpool call where the actual db.commit()
happens — the mutation only ever lands on that dependency's private copy,
which is discarded when it returns. This was verified the hard way: an
initial version set the actor from inside get_auth_context, and every
audit_events row for an authenticated mutation came back with
actor_id=NULL.

The fix is the same shape as request_id: resolve the actor in
RequestContextMiddleware, in the ambient async context, *before* calling
call_next() — every downstream threadpool copy (each dependency, the
route handler) is taken after that point, so all of them see it.
"""
import contextvars
from uuid import UUID

from jose import JWTError, jwt

from app.core.config import settings

_actor_id: contextvars.ContextVar[UUID | None] = contextvars.ContextVar("audit_actor_id", default=None)
_actor_ip: contextvars.ContextVar[str | None] = contextvars.ContextVar("audit_actor_ip", default=None)
_request_id: contextvars.ContextVar[str | None] = contextvars.ContextVar("audit_request_id", default=None)


def resolve_actor_id(authorization_header: str | None) -> UUID | None:
    """Best-effort, no DB round trip: just enough to attribute an audit
    row to a user id. Deliberately doesn't check revocation or
    tokens_valid_after — if the token turns out to be invalid/revoked,
    get_current_user's own dependency chain rejects the request before
    the route handler (and therefore any db.commit()) ever runs, so
    there's nothing to attribute in that case anyway.
    """
    if not authorization_header or not authorization_header.lower().startswith("bearer "):
        return None
    token = authorization_header[7:]
    try:
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
    except JWTError:
        return None
    sub = payload.get("sub")
    if not sub:
        return None
    try:
        return UUID(sub)
    except ValueError:
        return None


def set_actor_id(user_id: UUID | None) -> None:
    # Stays a UUID object, never stringified — it's bound straight into a
    # UUID-typed column. A str broke SQLite's UUID bind processor the same
    # way it did for RefreshToken.user_id in SEC-01.
    _actor_id.set(user_id)


def set_request_info(ip: str | None, request_id: str | None) -> None:
    _actor_ip.set(ip)
    _request_id.set(request_id)


def get_actor_id() -> UUID | None:
    return _actor_id.get()


def get_actor_ip() -> str | None:
    return _actor_ip.get()


def get_request_id() -> str | None:
    return _request_id.get()
