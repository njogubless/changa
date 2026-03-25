import base64
import httpx
from datetime import datetime, timezone
from app.core.config import settings


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


async def stk_push(phone: str, amount: float, reference: str, description: str = "Changa Contribution") -> dict:
    """Initiate M-Pesa STK Push. Returns Daraja API response."""
    token = await get_access_token()
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
        response.raise_for_status()
        return response.json()


def parse_callback(body: dict) -> dict:
    """
    Parse Safaricom STK Push callback body.
    Returns: { success, amount, receipt, phone, failure_reason }
    """
    stk_callback = body.get("Body", {}).get("stkCallback", {})
    result_code = stk_callback.get("ResultCode")

    if result_code != 0:
        return {
            "success": False,
            "failure_reason": stk_callback.get("ResultDesc", "Payment failed"),
        }

    items = {
        item["Name"]: item.get("Value")
        for item in stk_callback.get("CallbackMetadata", {}).get("Item", [])
    }

    return {
        "success": True,
        "amount": float(items.get("Amount", 0)),
        "receipt": items.get("MpesaReceiptNumber"),
        "phone": str(items.get("PhoneNumber", "")),
        "failure_reason": None,
    }
