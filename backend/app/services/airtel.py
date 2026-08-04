import httpx
from decimal import Decimal
from app.core.config import settings
from app.core.types import to_money, is_whole_currency_unit, ProviderPrecisionError


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

    token = await get_access_token()

    
    airtel_phone = phone.replace("254", "0", 1) if phone.startswith("254") else phone

    payload = {
        "reference": reference,
        "subscriber": {"country": "KE", "currency": "KES", "msisdn": airtel_phone},
        "transaction": {"amount": int(amount), "country": "KE", "currency": "KES", "id": reference},
    }

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
        response.raise_for_status()
        return response.json()


async def query_transaction_status(reference: str) -> dict:
    """Ask Airtel directly whether this transaction reference completed.

    Mirrors mpesa.query_stk_status: the callback body is unauthenticated
    and must never be trusted on its own (see PAY-01). This requires our
    own Airtel credentials to call, so its answer can't be forged by a
    third party the way a POSTed callback body can.
    """
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

    if response.status_code != 200:
        return {"success": False, "receipt": None}

    transaction = response.json().get("data", {}).get("transaction", {})
    success = transaction.get("status") == "TS"
    return {"success": success, "receipt": transaction.get("airtel_money_id")}


def parse_callback(body: dict) -> dict:
    """
    Parse Airtel Money callback.
    Returns: { success, amount, receipt, phone, failure_reason }
    """
    transaction = body.get("transaction", {})
    status_code = transaction.get("status_code", "")

    if status_code == "TS":
        return {
            "success": True,
            "amount": to_money(transaction.get("amount", 0)),
            "receipt": transaction.get("airtel_money_id"),
            "phone": transaction.get("msisdn", ""),
            "failure_reason": None,
        }

    return {
        "success": False,
        "failure_reason": transaction.get("message", "Payment failed"),
    }
