import httpx
from decimal import Decimal
from app.core.config import settings
from app.core.types import is_whole_currency_unit, ProviderPrecisionError
from app.services.provider_errors import (
    ProviderOutcome, ProviderAmbiguousError, ProviderRejectedError, ProviderRetryableError,
    classify_push_response, classify_send_error,
)


async def get_access_token() -> str:
    async with httpx.AsyncClient() as client:
        response = await client.post(
            f"{settings.AIRTEL_BASE_URL}/auth/oauth2/token",
            json={
                "client_id": settings.AIRTEL_CLIENT_ID,
                "client_secret": settings.AIRTEL_CLIENT_SECRET,
                "grant_type": "client_credentials",
            },
            headers={"Content-Type": "application/json"},
            timeout=10.0,
        )
        response.raise_for_status()
        return response.json()["access_token"]


async def initiate_payment(phone: str, amount: Decimal, reference: str) -> dict:
    """Initiate Airtel Money payment."""
    if not is_whole_currency_unit(amount):
        raise ProviderPrecisionError("Airtel Money accepts whole shillings only")

    try:
        token = await get_access_token()
    except (httpx.HTTPError, KeyError, ValueError) as exc:
        raise ProviderRetryableError(f"Airtel OAuth failed: {type(exc).__name__}") from exc

    airtel_phone = phone.replace("254", "0", 1) if phone.startswith("254") else phone

    payload = {
        "reference": reference,
        "subscriber": {"country": "KE", "currency": "KES", "msisdn": airtel_phone},
        "transaction": {"amount": int(amount), "country": "KE", "currency": "KES", "id": reference},
    }

    try:
        async with httpx.AsyncClient() as client:
            response = await client.post(
                f"{settings.AIRTEL_BASE_URL}/merchant/v1/payments/",
                json=payload,
                headers={
                    "Authorization": f"Bearer {token}",
                    "Content-Type": "application/json",
                    "X-Country": "KE",
                    "X-Currency": "KES",
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
        raise ProviderAmbiguousError("unparseable Airtel payment response") from exc
    if (body.get("status") or {}).get("success") is False:
        raise ProviderRejectedError(
            f"Airtel did not accept the payment (code={(body.get('status') or {}).get('response_code')!r})"
        )
    return body


async def query_transaction_status(reference: str) -> dict:
    """Ask Airtel directly whether this transaction reference completed.

    Mirrors mpesa.query_stk_status: the callback body is unauthenticated
    and must never be trusted on its own (see PAY-01). This requires our
    own Airtel credentials to call, so its answer can't be forged by a
    third party the way a POSTed callback body can.

    Transaction status codes: TS = success, TF = failed; anything else
    (TIP in progress, TA ambiguous, missing) and any transport/HTTP error is
    UNKNOWN — the contribution stays PENDING and is asked about again.
    Returns {"outcome": ProviderOutcome, "receipt": str | None, "reason": str | None}.
    """
    try:
        token = await get_access_token()
        async with httpx.AsyncClient() as client:
            response = await client.get(
                f"{settings.AIRTEL_BASE_URL}/standard/v1/payments/{reference}",
                headers={
                    "Authorization": f"Bearer {token}",
                    "Content-Type": "application/json",
                    "X-Country": "KE",
                    "X-Currency": "KES",
                },
                timeout=15.0,
            )
        body = response.json() if response.status_code == 200 else None
    except (httpx.HTTPError, KeyError, ValueError) as exc:
        return {"outcome": ProviderOutcome.UNKNOWN, "receipt": None, "reason": f"query error: {type(exc).__name__}"}

    if body is None:
        return {"outcome": ProviderOutcome.UNKNOWN, "receipt": None, "reason": f"query returned HTTP {response.status_code}"}

    transaction = (body.get("data") or {}).get("transaction") or {}
    status = transaction.get("status")
    if status == "TS":
        return {"outcome": ProviderOutcome.SUCCESS, "receipt": transaction.get("airtel_money_id"), "reason": None}
    if status == "TF":
        return {"outcome": ProviderOutcome.FAILED, "receipt": None, "reason": transaction.get("message") or "TF"}
    return {"outcome": ProviderOutcome.UNKNOWN, "receipt": None, "reason": f"transaction status {status!r}"}
