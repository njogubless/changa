import httpx
from app.core.config import settings


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


async def initiate_payment(phone: str, amount: float, reference: str) -> dict:
    """Initiate Airtel Money payment."""
    token = await get_access_token()

    # Airtel expects phone without country code prefix
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
            "amount": float(transaction.get("amount", 0)),
            "receipt": transaction.get("airtel_money_id"),
            "phone": transaction.get("msisdn", ""),
            "failure_reason": None,
        }

    return {
        "success": False,
        "failure_reason": transaction.get("message", "Payment failed"),
    }
