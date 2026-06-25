
import secrets
import string
from datetime import datetime, timezone
from sqlalchemy.orm import Session
from app.models.models import ChamaInvite, User, InviteStatus


def generate_invite_code(length: int = 8) -> str:
    """
    Generates a human-friendly uppercase code — no 0/O/I/1 confusion.
    Example output: 'CHNG-X7KP'
    """
    alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
    raw = "".join(secrets.choice(alphabet) for _ in range(length))
    return f"CHNG-{raw[:4]}"


def get_pending_invite_for_user(
    db: Session,
    chama_id: str,
    user_id: str,
) -> ChamaInvite | None:
    """Check if user already has a pending invite to this chama."""
    return db.query(ChamaInvite).filter(
        ChamaInvite.chama_id == chama_id,
        ChamaInvite.user_id == user_id,
        ChamaInvite.status == InviteStatus.PENDING,
    ).first()


def get_pending_invite_for_phone(
    db: Session,
    chama_id: str,
    phone: str,
) -> ChamaInvite | None:
    """Check if phone already has a pending invite to this chama."""
    return db.query(ChamaInvite).filter(
        ChamaInvite.chama_id == chama_id,
        ChamaInvite.phone == phone,
        ChamaInvite.status == InviteStatus.PENDING,
    ).first()


def mark_expired_invites(db: Session) -> None:
    """Mark all past-expiry pending invites as expired. Run periodically."""
    now = datetime.now(timezone.utc)
    db.query(ChamaInvite).filter(
        ChamaInvite.status == InviteStatus.PENDING,
        ChamaInvite.expires_at < now,
    ).update({"status": InviteStatus.EXPIRED})
    db.commit()


def resolve_phone_invites_for_user(db: Session, user: User) -> None:
    """
    Called after a new user registers.
    Links any phone-based pending invites to their new user_id
    so they appear in their notification inbox immediately.
    """
    db.query(ChamaInvite).filter(
        ChamaInvite.phone == str(user.phone),
        ChamaInvite.user_id == None,
        ChamaInvite.status == InviteStatus.PENDING,
    ).update({"user_id": user.id})
    db.commit()
