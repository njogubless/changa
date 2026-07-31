from dataclasses import dataclass
from jose import JWTError, jwt
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.orm import Session
import bcrypt

from app.core.config import settings
from app.core.tokens import is_access_token_revoked
from app.database import get_db
from app.models.models import User

bearer_scheme = HTTPBearer()


def hash_password(password: str) -> str:
    return bcrypt.hashpw(password.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")


def verify_password(plain: str, hashed: str) -> bool:
    return bcrypt.checkpw(plain.encode("utf-8"), hashed.encode("utf-8"))


def decode_token(token: str) -> dict:
    try:
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
        return payload
    except JWTError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token",
            headers={"WWW-Authenticate": "Bearer"},
        )


@dataclass
class AuthContext:
    user: User
    jti: str | None
    iat: int | None


def get_auth_context(
    credentials: HTTPAuthorizationCredentials = Depends(bearer_scheme),
    db: Session = Depends(get_db),
) -> AuthContext:
    """Decodes and fully validates the bearer token, including revocation.

    Single entry point so every caller (get_current_user for the common
    case, get_current_token_context where the jti/iat is needed to act on
    the current session specifically, e.g. logout) gets the same checks —
    FastAPI caches this per request, so using both costs one decode, not
    two.
    """
    payload = decode_token(credentials.credentials)

    if payload.get("type") != "access":
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token type")

    user_id: str = payload.get("sub")
    if not user_id:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token")

    jti = payload.get("jti")
    if jti and is_access_token_revoked(db, jti):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Token revoked")

    user = db.query(User).filter(User.id == user_id, User.is_active == True).first()
    if not user:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="User not found")

    # Bulk invalidation: logout-all-sessions, password change or an admin
    # disabling the account bump tokens_valid_after, so every access token
    # issued before that moment stops working within its own (short)
    # remaining lifetime instead of never. See SEC-01.
    iat = payload.get("iat")
    if user.tokens_valid_after is not None and iat is not None:
        if iat < int(user.tokens_valid_after.timestamp()):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Session expired — please sign in again",
            )

    return AuthContext(user=user, jti=jti, iat=iat)


def get_current_user(ctx: AuthContext = Depends(get_auth_context)):
    return ctx.user


def get_current_token_context(ctx: AuthContext = Depends(get_auth_context)) -> AuthContext:
    return ctx
