from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from datetime import datetime, timezone

from app.database import get_db
from app.core.config import settings
from app.core.security import (
    hash_password, verify_password, DUMMY_PASSWORD_HASH,
    get_current_user, get_current_token_context, AuthContext,
)
from app.core.tokens import (
    create_access_token, create_refresh_token_row, hash_refresh_token,
    revoke_family, revoke_all_sessions, revoke_access_token,
)
from app.core.ratelimit import (
    rate_limit_dependency, check_not_locked_out,
    record_login_failure, clear_login_failures,
)
from app.models.models import User, RefreshToken
from app.schemas.auth import (
    RegisterRequest, LoginRequest, LoginResponse,
    TokenResponse, RefreshRequest, UserResponse, ChangePasswordRequest,
)

router = APIRouter(prefix="/auth", tags=["Auth"])


def _issue_session(db: Session, user: User) -> tuple[str, str]:
    """New login: a fresh refresh-token family, plus an access token."""
    access_token = create_access_token(str(user.id))
    # user.id stays a UUID object here — it's bound into a UUID-typed
    # column, not encoded as a JWT claim, so it must not be stringified
    # (a plain str broke the SQLite dialect's UUID bind processor and is
    # inconsistent typing even against Postgres).
    raw_refresh, _ = create_refresh_token_row(db, user.id)
    return access_token, raw_refresh


@router.post(
    "/register", response_model=LoginResponse, status_code=201,
    dependencies=[Depends(rate_limit_dependency("auth:register"))],
)
def register(payload: RegisterRequest, db: Session = Depends(get_db)):
    if db.query(User).filter(User.email == payload.email).first():
        raise HTTPException(status_code=400, detail="Email already registered")
    if db.query(User).filter(User.phone == payload.phone).first():
        raise HTTPException(status_code=400, detail="Phone number already registered")

    user = User(
        full_name=payload.full_name,
        email=payload.email,
        phone=payload.phone,
        hashed_password=hash_password(payload.password),
    )
    db.add(user)
    db.flush()

    access_token, refresh_token = _issue_session(db, user)
    db.commit()
    db.refresh(user)

    return LoginResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        user=UserResponse.model_validate(user),
    )


@router.post(
    "/login", response_model=LoginResponse,
    dependencies=[Depends(rate_limit_dependency("auth:login"))],
)
def login(payload: LoginRequest, db: Session = Depends(get_db)):
    # Per-account progressive lockout — independent of the per-IP flood
    # guard above, this protects one specific account from credential
    # stuffing regardless of how many source IPs the attempts come from.
    check_not_locked_out(payload.email)

    user = db.query(User).filter(User.email == payload.email, User.is_active == True).first()

    # Always run a full bcrypt comparison, even for an email that doesn't
    # exist — otherwise a nonexistent-email request returns near-instantly
    # while a real one takes ~100ms, and that timing difference alone lets
    # an attacker enumerate registered emails (see SEC-03).
    password_ok = verify_password(
        payload.password, user.hashed_password if user else DUMMY_PASSWORD_HASH,
    )

    if not user or not password_ok:
        record_login_failure(payload.email)
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password",
        )

    clear_login_failures(payload.email)
    access_token, refresh_token = _issue_session(db, user)
    db.commit()

    return LoginResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        user=UserResponse.model_validate(user),
    )


@router.post(
    "/refresh", response_model=TokenResponse,
    dependencies=[Depends(rate_limit_dependency("auth:refresh"))],
)
def refresh(payload: RefreshRequest, db: Session = Depends(get_db)):
    presented_hash = hash_refresh_token(payload.refresh_token)
    stored = db.query(RefreshToken).filter(
        RefreshToken.token_hash == presented_hash,
    ).first()
    if stored is None:
        raise HTTPException(status_code=401, detail="Invalid refresh token")

    if stored.consumed_at is not None or stored.revoked_at is not None:
        # Replay of a token that was already used (or already revoked) is
        # the canonical signal that it was stolen — kill the whole device
        # family rather than just rejecting this one request, so the
        # thief's still-valid sibling token stops working too. See SEC-01.
        revoke_family(db, stored.family_id, reason="reuse")
        db.commit()
        raise HTTPException(status_code=401, detail="Session invalidated. Please sign in again.")

    if stored.expires_at < datetime.now(timezone.utc):
        stored.revoked_at = datetime.now(timezone.utc)
        stored.revoked_reason = "expired"
        db.commit()
        raise HTTPException(status_code=401, detail="Refresh token expired")

    stored.consumed_at = datetime.now(timezone.utc)
    new_refresh, _ = create_refresh_token_row(db, stored.user_id, family_id=stored.family_id)
    new_access = create_access_token(str(stored.user_id))
    db.commit()

    return TokenResponse(access_token=new_access, refresh_token=new_refresh)


@router.post("/logout")
def logout(
    payload: RefreshRequest,
    db: Session = Depends(get_db),
    ctx: AuthContext = Depends(get_current_token_context),
):
    stored = db.query(RefreshToken).filter(
        RefreshToken.token_hash == hash_refresh_token(payload.refresh_token),
        RefreshToken.user_id == ctx.user.id,
    ).first()
    if stored:
        revoke_family(db, stored.family_id, reason="logout")

    # Revoke the access token in hand too — before this, logout only ever
    # touched the refresh token, so the still-live access token kept
    # working for the rest of its lifetime regardless (see SEC-01). exp is
    # bounded by ACCESS_TOKEN_EXPIRE_MINUTES from iat, both already
    # verified by decode_token when this request authenticated.
    if ctx.jti and ctx.iat:
        expires_at = datetime.fromtimestamp(
            ctx.iat + settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60, tz=timezone.utc,
        )
        revoke_access_token(db, ctx.jti, expires_at)

    db.commit()
    return {"detail": "Successfully logged out"}


@router.get("/me", response_model=UserResponse)
def me(current_user: User = Depends(get_current_user)):
    return UserResponse.model_validate(current_user)


@router.post("/change-password")
def change_password(
    payload: ChangePasswordRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if not verify_password(payload.current_password, current_user.hashed_password):
        raise HTTPException(status_code=400, detail="Current password is incorrect")
    current_user.hashed_password = hash_password(payload.new_password)

    # Every session — every device — is invalidated on a password change,
    # not just the refresh tokens: tokens_valid_after also cuts off any
    # access token already issued (see SEC-01).
    revoke_all_sessions(db, str(current_user.id), reason="password_change")

    db.commit()
    return {"detail": "Password changed successfully"}
