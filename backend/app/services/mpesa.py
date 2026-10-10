import base64
import httpx
from decimal import Decimal
from datetime import datetime, timezone
from app.core.config import settings
from app.core.types import is_whole_currency_unit, ProviderPrecisionError
from app.services.provider_errors import (
    ProviderOutcome, ProviderAmbiguousError, ProviderRejectedError, ProviderRetryableError,
    classify_push_response, classify_send_error,
)


def _get_timestamp() -> str:
    return datetime.now(timezone.utc).strftime("%Y%m%d%H%M%S")


def _get_password(timestamp: str) -> str:
    raw = f"{settings.MPESA_SHORTCODE}{settings.MPESA_PASSKEY}{timestamp}"
    return base64.b64encode(raw.encode()).decode()


async def get_access_token() -> str:
    credentials = base64.b64encode(
        f"{settings.MPESA_CONSUMER_KEY}:{settings.MPESA_CONSUMER_SECRET}".encode()
    ).decode()

    async with httpx.AsyncClient() as client:
        response = await client.get(
            f"{settings.MPESA_BASE_URL}/oauth/v1/generate?grant_type=client_credentials",
            headers={"Authorization": f"Basic {credentials}"},
            timeout=10.0,
        )
        response.raise_for_status()
        return response.json()["access_token"]


async def stk_push(phone: str, amount: Decimal, reference: str, description: str = "Changa Contribution") -> dict:
    """Initiate M-Pesa STK Push. Returns Daraja API response."""
    # Daraja accepts whole KES only. The schema layer (MpesaContributeRequest)
    # already rejects fractional amounts, but never silently truncate cents
    # here even so — that used to request less from M-Pesa than the ledger
    # recorded, guaranteeing a permanent discrepancy (FIN-01).
    if not is_whole_currency_unit(amount):
        raise ProviderPrecisionError("M-Pesa STK Push accepts whole shillings only")

    try:
        token = await get_access_token()
    except (httpx.HTTPError, KeyError, ValueError) as exc:
        # No push has been sent yet, so this is always safe to retry.
        raise ProviderRetryableError(f"M-Pesa OAuth failed: {type(exc).__name__}") from exc
    timestamp = _get_timestamp()

    payload = {
        "BusinessShortCode": settings.MPESA_SHORTCODE,
        "Password": _get_password(timestamp),
        "Timestamp": timestamp,
        "TransactionType": "CustomerPayBillOnline",
        "Amount": int(amount),
        "PartyA": phone,
        "PartyB": settings.MPESA_SHORTCODE,
        "PhoneNumber": phone,
        "CallBackURL": settings.MPESA_CALLBACK_URL,
        "AccountReference": reference,
        "TransactionDesc": description,
    }

    try:
        async with httpx.AsyncClient() as client:
            response = await client.post(
                f"{settings.MPESA_BASE_URL}/mpesa/stkpush/v1/processrequest",
                json=payload,
                headers={
                    "Authorization": f"Bearer {token}",
                    "Content-Type": "application/json",
                },
                timeout=15.0,
            )
    except httpx.HTTPError as exc:
        raise classify_send_error(exc) from exc

    error = classify_push_response(response)
    if error is not None:
        raise error
    try:
        body = response.json()
    except ValueError as exc:
        raise ProviderAmbiguousError("unparseable STK push response") from exc

    # Daraja only issues a CheckoutRequestID for a push it accepted; without
    # one there is no prompt on the payer's phone and nothing to query later.
    if str(body.get("ResponseCode")) != "0" or not body.get("CheckoutRequestID"):
        raise ProviderRejectedError(f"STK push not accepted (ResponseCode={body.get('ResponseCode')!r})")
    return body


async def query_stk_status(checkout_request_id: str) -> dict:
    """Ask Safaricom directly whether this specific push completed.

    The push *callback* is an unauthenticated, unsigned POST to a public
    URL — anyone who can reach it can forge a success body for any
    contribution (see PAY-01). This query is the authoritative check: it
    requires our own Daraja credentials to call, so its answer cannot be
    forged by a third party the way the callback body can.

    Returns {"outcome": ProviderOutcome, "reason": str | None}:
      - HTTP 200 with ResultCode "0"            -> SUCCESS
      - HTTP 200 with any other ResultCode      -> FAILED (cancelled by user,
        insufficient funds, wrong PIN, timed out on the handset, ...)
      - anything else — non-200 (Daraja answers HTTP 500 / errorCode
        500.001.1001 "The transaction is being processed" while the payer
        is still on the PIN prompt), a missing ResultCode, a network error
        -> UNKNOWN. Never FAILED: no definitive answer is not a failure.

    The amount ever credited is always the amount *we* initiated the push
    for (see ledger_service.credit_contribution), never a value read from
    an unauthenticated source, so the query only needs to answer "did this
    specific CheckoutRequestID actually complete".
    """
    try:
        token = await get_access_token()
        timestamp = _get_timestamp()
        payload = {
            "BusinessShortCode": settings.MPESA_SHORTCODE,
            "Password": _get_password(timestamp),
            "Timestamp": timestamp,
            "CheckoutRequestID": checkout_request_id,
        }
        async with httpx.AsyncClient() as client:
            response = await client.post(
                f"{settings.MPESA_BASE_URL}/mpesa/stkpushquery/v1/query",
                json=payload,
                headers={
                    "Authorization": f"Bearer {token}",
                    "Content-Type": "application/json",
                },
                timeout=15.0,
            )
        body = response.json() if response.status_code == 200 else None
    except (httpx.HTTPError, KeyError, ValueError) as exc:
        return {"outcome": ProviderOutcome.UNKNOWN, "reason": f"query error: {type(exc).__name__}"}

    if body is None:
        return {"outcome": ProviderOutcome.UNKNOWN, "reason": f"query returned HTTP {response.status_code}"}

    result_code = body.get("ResultCode")
    if result_code is None:
        return {"outcome": ProviderOutcome.UNKNOWN, "reason": "query response had no ResultCode"}
    if str(result_code) == "0":
        return {"outcome": ProviderOutcome.SUCCESS, "reason": None}
    return {"outcome": ProviderOutcome.FAILED, "reason": f"ResultCode {result_code}: {body.get('ResultDesc')}"}
