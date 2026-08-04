"""Session/token issuance, rotation and revocation.

Split out from core/security.py (which keeps password hashing) because
this module encodes the session-management model described in SEC-01 of
docs/Changa_Engineering_audit.md: refresh tokens are opaque secrets stored
only as a hash, grouped into rotation families so replay of a consumed
token is detectable, and access tokens carry a `jti` so they can be
individually revoked before their natural expiry.
"""
import hashlib
import secrets
import uuid
from datetime import datetime, timedelta, timezone

from jose import jwt
from sqlalchemy.orm import Session

from app.core.config import settings
from app.models.models import RefreshToken, RevokedAccessToken, User


def create_access_token(user_id: str) -> str:
    now = datetime.now(timezone.utc)
    payload = {
        "sub": user_id,
        "jti": str(uuid.uuid4()),
        "iat": int(now.timestamp()),
        "exp": now + timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES),
        "type": "access",
    }
    return jwt.encode(payload, settings.SECRET_KEY, algorithm=settings.ALGORITHM)


def issue_refresh_token() -> tuple[str, str]:
    """Returns (raw_token_for_the_client, sha256_hex_digest_to_store)."""
    raw = secrets.token_urlsafe(48)  # opaque, 384 bits — never a JWT, needs no claims
    digest = hashlib.sha256(raw.encode()).hexdigest()
    return raw, digest


def hash_refresh_token(raw: str) -> str:
    return hashlib.sha256(raw.encode()).hexdigest()


def create_refresh_token_row(db: Session, user_id, family_id: uuid.UUID | None = None) -> tuple[str, RefreshToken]:
    """Issues and persists a new refresh token, optionally continuing an
    existing rotation family (pass the previous token's family_id when
    rotating; omit it to start a new family, i.e. a fresh login)."""
    raw, digest = issue_refresh_token()
    row = RefreshToken(
        user_id=user_id,
        token_hash=digest,
        family_id=family_id or uuid.uuid4(),
        expires_at=datetime.now(timezone.utc) + timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS),
    )
    db.add(row)
    return raw, row


def revoke_family(db: Session, family_id: uuid.UUID, reason: str) -> None:
    """Revoke every not-yet-revoked token in a rotation family.

    Used both for a clean logout (kill this device's session) and for
    reuse detection (kill the whole chain because a consumed token being
    presented again means it was stolen — see SEC-01).
    """
    now = datetime.now(timezone.utc)
    db.query(RefreshToken).filter(
        RefreshToken.family_id == family_id,
        RefreshToken.revoked_at.is_(None),
    ).update({"revoked_at": now, "revoked_reason": reason}, synchronize_session=False)


def revoke_all_sessions(db: Session, user_id: str, reason: str) -> None:
    """Revoke every refresh token family for a user — password change,
    admin-disable, or a user-initiated 'log out everywhere'."""
    now = datetime.now(timezone.utc)
    db.query(RefreshToken).filter(
        RefreshToken.user_id == user_id,
        RefreshToken.revoked_at.is_(None),
    ).update({"revoked_at": now, "revoked_reason": reason}, synchronize_session=False)
    db.query(User).filter(User.id == user_id).update(
        {"tokens_valid_after": now}, synchronize_session=False,
    )


def revoke_access_token(db: Session, jti: str, expires_at: datetime) -> None:
    """Deny-list a single access token by its jti — e.g. on logout, so the
    token in hand stops working immediately rather than at its natural
    (short) expiry."""
    if db.get(RevokedAccessToken, jti) is None:
        db.add(RevokedAccessToken(jti=jti, expires_at=expires_at))


def is_access_token_revoked(db: Session, jti: str) -> bool:
    return db.get(RevokedAccessToken, jti) is not None
