"""Outcome vocabulary shared by the M-Pesa and Airtel integrations.

Two distinctions matter for money and were previously collapsed:

1. A status query has three answers, not two. "The provider says it
   failed" and "we could not get an answer" (HTTP error, timeout, Daraja's
   "transaction is being processed") used to both come back as
   `success=False`, and the callback path then marked the contribution
   FAILED — so a payment that actually completed, but whose verification
   query hit a transient error, was recorded as failed and dropped out of
   the reconciliation sweep (which only looks at PENDING) for good.

2. An initiation error has three meanings, not one. Retrying a push that
   never reached the provider is safe; retrying one the provider may have
   accepted can prompt the payer twice and charge them twice, with only one
   CheckoutRequestID ever recorded.
"""
import enum

import httpx


class ProviderOutcome(str, enum.Enum):
    SUCCESS = "success"   # provider confirmed the money moved
    FAILED = "failed"     # provider gave a definitive non-success answer
    UNKNOWN = "unknown"   # no definitive answer yet — leave PENDING, ask again later


class ProviderRetryableError(Exception):
    """The request provably never reached the provider (connection refused,
    connect timeout, couldn't obtain an OAuth token). Safe to retry."""


class ProviderRejectedError(Exception):
    """The provider answered and did not accept the request. No payment
    prompt exists, so the contribution can be marked FAILED."""


class ProviderAmbiguousError(Exception):
    """The request may or may not have been processed (read timeout, dropped
    connection, gateway 502/503/504, unparseable body). Never retry the push
    — leave the contribution PENDING for the reconciliation sweep."""


# Gateway errors can be returned after the upstream already processed the
# request, so they don't prove the push was not created.
_AMBIGUOUS_STATUSES = {502, 503, 504}


def classify_send_error(exc: httpx.HTTPError) -> Exception:
    """Map a transport error raised while *sending* a push request."""
    if isinstance(exc, (httpx.ConnectError, httpx.ConnectTimeout, httpx.PoolTimeout)):
        return ProviderRetryableError(f"{type(exc).__name__}: request not sent")
    return ProviderAmbiguousError(f"{type(exc).__name__}: outcome unknown")


def classify_push_response(response: httpx.Response) -> Exception | None:
    """None if the HTTP status looks like a normal answer; otherwise the error
    to raise. 4xx and 500 are the provider refusing the request."""
    if response.status_code in _AMBIGUOUS_STATUSES:
        return ProviderAmbiguousError(f"HTTP {response.status_code}")
    if response.status_code >= 400:
        return ProviderRejectedError(f"HTTP {response.status_code}")
    return None
