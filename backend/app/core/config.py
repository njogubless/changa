from pydantic_settings import BaseSettings
from pydantic import field_validator
from typing import List


class Settings(BaseSettings):
    # App
    APP_NAME: str = "Changa"
    DEBUG: bool = False
    SECRET_KEY: str
    ALLOWED_HOSTS: List[str] = ["http://localhost:3000", "http://127.0.0.1:3000"]
    ENVIRONMENT: str = "development"

    # Observability (see OBS-01). Empty DSN disables Sentry rather than
    # erroring — most local/dev/CI runs have no DSN configured.
    SENTRY_DSN: str = ""

    # Database
    DATABASE_URL: str

    # JWT
    ALGORITHM: str = "HS256"
    # Shorter than before (was 30): access tokens can now be revoked
    # (RevokedAccessToken, User.tokens_valid_after — see SEC-01), but that
    # revocation only takes effect on the next request either way. A
    # shorter lifetime bounds how long a token can keep working if it is
    # ever compromised and the deny-list check is somehow bypassed.
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 15
    REFRESH_TOKEN_EXPIRE_DAYS: int = 7

    # M-Pesa
    MPESA_CONSUMER_KEY: str = ""
    MPESA_CONSUMER_SECRET: str = ""
    MPESA_SHORTCODE: str = "174379"
    MPESA_PASSKEY: str = ""
    MPESA_CALLBACK_URL: str = ""
    MPESA_BASE_URL: str = "https://sandbox.safaricom.co.ke"
    # Opaque path secret the callback URL must embed — see PAY-01. Without
    # this, anyone who can reach the callback route can forge a "payment
    # succeeded" event for any contribution.
    MPESA_CALLBACK_TOKEN: str = ""

    # Airtel
    AIRTEL_CLIENT_ID: str = ""
    AIRTEL_CLIENT_SECRET: str = ""
    AIRTEL_BASE_URL: str = "https://openapiuat.airtel.africa"
    AIRTEL_CALLBACK_URL: str = ""
    AIRTEL_CALLBACK_TOKEN: str = ""

    @field_validator("DATABASE_URL")
    @classmethod
    def validate_db_url(cls, v: str) -> str:
        if not v.startswith("postgresql"):
            raise ValueError("DATABASE_URL must be a PostgreSQL URL")
        return v

    model_config = {"env_file": ".env", "env_file_encoding": "utf-8"}


settings = Settings()
