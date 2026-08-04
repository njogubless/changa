"""Rate limiting and progressive login lockout.

Before this, the only middleware registered anywhere was CORS: every
endpoint accepted unlimited requests from any source, including
/auth/login (credential stuffing), /auth/register, /chamas/join (invite
code enumeration) and /contributions/{provider} (unlimited real STK
pushes at the platform's expense — Safaricom will suspend the shortcode
for this). See SEC-03 in docs/Changa_Engineering_audit.md.

Implemented as an in-process, in-memory sliding window rather than a
Redis-backed one: the deployment is a single replica today (see REL-01,
out of scope here), so there is no cross-instance state to share yet.
This module is the seam to swap for a Redis-backed limiter without
touching call sites once that topology changes — every call site goes
through `check_rate_limit` / `record_login_failure` etc., never a raw
dict.
"""
import time
import threading
from collections import defaultdict, deque

from fastapi import HTTPException, Request

_lock = threading.Lock()
_buckets: dict[str, deque] = defaultdict(deque)
_login_failures: dict[str, deque] = defaultdict(deque)

# (max requests, window in seconds) per bucket.
LIMITS: dict[str, tuple[int, float]] = {
    "auth:login": (20, 300),        # generic flood guard, per IP
    "auth:register": (3, 3600),
    "auth:refresh": (30, 300),
    "chama:join": (10, 3600),
    "payment:initiate": (5, 300),
}

# Progressive lockout thresholds, keyed by email — independent of the
# generic per-IP flood guard above, this protects one specific account
# from credential stuffing regardless of how many IPs the attempts come
# from. (failure_count_threshold, lockout_seconds), checked from the
# highest threshold down.
LOCKOUT_TIERS: list[tuple[int, float]] = [
    (10, 3600),   # 10 failures -> locked 1 hour
    (5, 900),     # 5 failures  -> locked 15 minutes
]
LOCKOUT_WINDOW_SECONDS = 3600  # failures older than this don't count


def _purge(dq: deque, window_seconds: float, now: float) -> None:
    while dq and dq[0] < now - window_seconds:
        dq.popleft()


def check_rate_limit(bucket: str, identity: str) -> None:
    """Raises HTTPException(429) if `identity` has exceeded `bucket`'s limit."""
    limit, window = LIMITS[bucket]
    now = time.monotonic()
    key = f"{bucket}:{identity}"
    with _lock:
        dq = _buckets[key]
        _purge(dq, window, now)
        if len(dq) >= limit:
            retry_after = int(window - (now - dq[0])) + 1
            raise HTTPException(
                status_code=429,
                detail="Too many requests. Please try again shortly.",
                headers={"Retry-After": str(max(retry_after, 1))},
            )
        dq.append(now)


def rate_limit_dependency(bucket: str):
    """FastAPI dependency factory — keys by client IP, for routes with no
    authenticated user yet (login, register, refresh)."""
    def dependency(request: Request) -> None:
        identity = request.client.host if request.client else "unknown"
        check_rate_limit(bucket, identity)
    return dependency


def record_login_failure(email: str) -> None:
    now = time.monotonic()
    with _lock:
        dq = _login_failures[email]
        _purge(dq, LOCKOUT_WINDOW_SECONDS, now)
        dq.append(now)


def clear_login_failures(email: str) -> None:
    with _lock:
        _login_failures.pop(email, None)


def reset_all() -> None:
    """Clears all in-memory rate-limit and lockout state.

    Not used by application code — this module's state is process-lifetime
    by design. Exists so the test suite can isolate tests from each other
    (see tests/conftest.py); without it, every test sharing TestClient's
    fixed source IP would exhaust auth:register's limit after 3 tests
    regardless of which test file it's in.
    """
    with _lock:
        _buckets.clear()
        _login_failures.clear()


def check_not_locked_out(email: str) -> None:
    """Raises HTTPException(423) if `email` is currently locked out from
    too many recent failed login attempts."""
    now = time.monotonic()
    with _lock:
        dq = _login_failures[email]
        _purge(dq, LOCKOUT_WINDOW_SECONDS, now)
        count = len(dq)
        last_failure = dq[-1] if dq else None

    if last_failure is None:
        return

    for threshold, lockout_seconds in LOCKOUT_TIERS:
        if count >= threshold:
            locked_until = last_failure + lockout_seconds
            if now < locked_until:
                raise HTTPException(
                    status_code=423,
                    detail="Account temporarily locked due to repeated failed login attempts. "
                           "Please try again later.",
                    headers={"Retry-After": str(int(locked_until - now) + 1)},
                )
            break
