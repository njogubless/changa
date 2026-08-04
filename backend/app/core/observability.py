"""Structured logging, request correlation and error tracking.

Before this there was not a single `logging.getLogger` call in the
codebase — `sentry-sdk` was pinned in requirements.txt but `.init()` was
never called, so it did nothing, and the only output was Uvicorn's access
log. Nobody could trace one user's failed contribution across the API,
the provider call and the callback, because no request ID tied them
together, and exceptions vanished into stdout. See OBS-01 in
docs/Changa_Engineering_audit.md.

Deliberately scoped down from the audit's illustrative version: this
service is sync SQLAlchemy on a single replica with no metrics/tracing
infrastructure (Prometheus scrape target, OTel collector) deployed
anywhere yet, so wiring Prometheus counters and OpenTelemetry
auto-instrumentation here would add operational dependencies nobody is
running — the same reasoning that kept SEC-03's rate limiter in-process
instead of Redis-backed (see REL-01, out of scope). What ships is the
part that's pure library code with no new infrastructure: JSON logs,
request-id correlation, and Sentry (already a pinned dependency, only
needs a DSN). Business-event log lines (payment.initiated,
payment.settled, ...) give the payment funnel visibility today; promoting
them to real counters is a mechanical follow-up once a metrics backend
exists.
"""
import logging
import time
import uuid

import sentry_sdk
import structlog
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request

from app.core.audit_context import resolve_actor_id, set_actor_id, set_request_info
from app.core.config import settings

# Field names that must never reach a log line or Sentry breadcrumb in the
# clear. Matched by exact key name, checked on every event dict.
REDACT = {
    "password", "hashed_password", "access_token", "refresh_token",
    "token", "raw_token", "MPESA_PASSKEY", "MPESA_CONSUMER_SECRET",
    "AIRTEL_CLIENT_SECRET", "SECRET_KEY",
}


def _redact(_, __, event_dict: dict) -> dict:
    for key in list(event_dict):
        if key in REDACT:
            event_dict[key] = "[redacted]"
    if "phone" in event_dict and event_dict["phone"]:
        # Keep the last 3 digits — enough for support to confirm they're
        # looking at the right ticket, not enough to be the phone number.
        event_dict["phone"] = f"***{str(event_dict['phone'])[-3:]}"
    return event_dict


def configure_observability(app) -> None:
    logging.basicConfig(format="%(message)s", level=logging.INFO)

    structlog.configure(
        processors=[
            structlog.contextvars.merge_contextvars,
            structlog.stdlib.add_log_level,
            structlog.processors.TimeStamper(fmt="iso"),
            _redact,
            structlog.processors.JSONRenderer(),
        ],
        wrapper_class=structlog.make_filtering_bound_logger(logging.INFO),
        logger_factory=structlog.stdlib.LoggerFactory(),
        cache_logger_on_first_use=True,
    )

    if settings.SENTRY_DSN:
        sentry_sdk.init(
            dsn=settings.SENTRY_DSN,
            environment=settings.ENVIRONMENT,
            traces_sample_rate=0.1,
            send_default_pii=False,
        )

    app.add_middleware(RequestContextMiddleware)


class RequestContextMiddleware(BaseHTTPMiddleware):
    """Binds a request id + route to every log line emitted while handling
    this request, and guarantees unhandled exceptions are logged before
    they propagate — nothing disappears into stdout unlogged."""

    async def dispatch(self, request: Request, call_next):
        log = structlog.get_logger("changa.request")
        request_id = request.headers.get("x-request-id") or str(uuid.uuid4())
        structlog.contextvars.bind_contextvars(
            request_id=request_id,
            route=request.url.path,
            method=request.method,
        )
        # Also feeds the audit trail (see REG-01) — the before_flush hook
        # has no access to the Request object otherwise. Resolving the
        # actor here, before call_next, is required, not just convenient —
        # see the module docstring on app/core/audit_context.py for why
        # setting it later, from inside get_auth_context, doesn't work.
        set_request_info(request.client.host if request.client else None, request_id)
        set_actor_id(resolve_actor_id(request.headers.get("authorization")))
        started = time.perf_counter()
        try:
            response = await call_next(request)
        except Exception:
            log.exception("request.unhandled")
            raise
        else:
            duration_ms = round((time.perf_counter() - started) * 1000, 2)
            response.headers["x-request-id"] = request_id
            log.info("request.completed", status=response.status_code, duration_ms=duration_ms)
            return response
        finally:
            structlog.contextvars.clear_contextvars()


def get_logger(name: str):
    return structlog.get_logger(name)
