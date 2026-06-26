
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from datetime import datetime, timezone, timedelta
from uuid import UUID
from typing import Optional

from app.database import get_db
from app.core.security import get_current_user
from app.models.models import (
    User, ChamaInvite, ChamaMember, Chama,
    InviteStatus, InviteMethod, ChamaMemberRole,
)
from app.services.invite_service import (
    generate_invite_code,
    get_pending_invite_for_user,
    get_pending_invite_for_phone,
)

router = APIRouter(prefix="/chamas", tags=["Chama Members"])


# ── Helper ─────────────────────────────────────────────────────────────────────

def _assert_chama_admin(chama_id: UUID, user: User, db: Session) -> Chama:
    chama = db.query(Chama).filter(Chama.id == chama_id).first()
    if not chama:
        raise HTTPException(status_code=404, detail="Chama not found")
    member = db.query(ChamaMember).filter(
        ChamaMember.chama_id == chama_id,
        ChamaMember.user_id == user.id,
        ChamaMember.role.in_([ChamaMemberRole.OWNER, ChamaMemberRole.ADMIN]),
    ).first()
    if not member:
        raise HTTPException(status_code=403, detail="Admin access required")
    return chama


def _build_invite_response(invite: ChamaInvite, db: Session) -> dict:
    chama = db.query(Chama).filter(Chama.id == invite.chama_id).first()
    inviter = db.query(User).filter(User.id == invite.invited_by).first()
    return {
        "id": str(invite.id),
        "chama_id": str(invite.chama_id),
        "chama_name": chama.name if chama else "Unknown",
        "chama_description": chama.description if chama else None,
        "invited_by_name": inviter.full_name if inviter else "Someone",
        "method": invite.method,
        "status": invite.status,
        "created_at": invite.created_at,
        "expires_at": invite.expires_at,
    }


# ── LIST MEMBERS ───────────────────────────────────────────────────────────────

@router.get("/{chama_id}/members")
def list_members(
    chama_id: UUID,
    status: Optional[str] = Query(None, description="Filter: pending | accepted | all"),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    GET /chamas/{chama_id}/members           → all active members
    GET /chamas/{chama_id}/members?status=pending  → pending invites only
    """
    _assert_chama_admin(chama_id, current_user, db)

    if status == "pending":
        invites = db.query(ChamaInvite).filter(
            ChamaInvite.chama_id == chama_id,
            ChamaInvite.status == InviteStatus.PENDING,
        ).all()
        return [_build_invite_response(i, db) for i in invites]

    members = db.query(ChamaMember).filter(
        ChamaMember.chama_id == chama_id,
    ).all()
    return [
        {
            "user_id": str(m.user_id),
            "full_name": m.user.full_name,
            "phone": str(m.user.phone),
            "role": m.role,
            "joined_at": m.joined_at,
        }
        for m in members
    ]


# ── INVITE BY PHONE ────────────────────────────────────────────────────────────

@router.post("/{chama_id}/members/invite")
def invite_by_phone(
    chama_id: UUID,
    payload: dict,  # { "phone": "254XXXXXXXXX" }
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Admin invites someone by their phone number.
    If the user exists → invite linked to their account immediately.
    If not registered yet → invite stored against phone number,
      resolved when they register.
    """
    chama = _assert_chama_admin(chama_id, current_user, db)
    phone = payload.get("phone", "").strip()

    if not phone:
        raise HTTPException(status_code=422, detail="Phone number is required")

    # Can't invite yourself
    if str(current_user.phone) == phone:
        raise HTTPException(status_code=400, detail="You can't invite yourself")

    # Check if already a member
    target_user = db.query(User).filter(User.phone == phone).first()
    if target_user:
        already = db.query(ChamaMember).filter(
            ChamaMember.chama_id == chama_id,
            ChamaMember.user_id == target_user.id,
        ).first()
        if already:
            raise HTTPException(status_code=400, detail="User is already a member")

        # Check for duplicate pending invite
        if get_pending_invite_for_user(db, str(chama_id), str(target_user.id)):
            raise HTTPException(status_code=400, detail="Invite already sent to this user")
    else:
        # User not registered yet — check for duplicate phone invite
        if get_pending_invite_for_phone(db, str(chama_id), phone):
            raise HTTPException(status_code=400, detail="Invite already sent to this number")

    invite = ChamaInvite(
        chama_id=chama_id,
        invited_by=current_user.id,
        phone=phone,
        user_id=target_user.id if target_user else None,
        method=InviteMethod.PHONE,
        status=InviteStatus.PENDING,
        expires_at=datetime.now(timezone.utc) + timedelta(days=7),
    )
    db.add(invite)
    db.commit()
    db.refresh(invite)

    return {
        "detail": f"Invite sent to {phone}",
        "invite_id": str(invite.id),
        "user_found": target_user is not None,
    }


# ── GENERATE INVITE CODE ───────────────────────────────────────────────────────

@router.post("/{chama_id}/members/invite-code")
def generate_code(
    chama_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Admin generates a shareable invite code.
    Code format: CHNG-XXXX (human friendly, no ambiguous chars).
    Valid for 7 days. Anyone with the code can join.
    """
    chama = _assert_chama_admin(chama_id, current_user, db)

    # Generate unique code
    for _ in range(10):  # retry on collision
        code = generate_invite_code()
        exists = db.query(ChamaInvite).filter(
            ChamaInvite.invite_code == code
        ).first()
        if not exists:
            break

    expires = datetime.now(timezone.utc) + timedelta(days=7)
    invite = ChamaInvite(
        chama_id=chama_id,
        invited_by=current_user.id,
        invite_code=code,
        method=InviteMethod.CODE,
        status=InviteStatus.PENDING,
        expires_at=expires,
    )
    db.add(invite)
    db.commit()

    return {
        "invite_code": code,
        "expires_at": expires,
        "chama_id": str(chama_id),
        "chama_name": chama.name,
    }


# ── JOIN BY CODE ───────────────────────────────────────────────────────────────

@router.post("/join")
def join_by_code(
    payload: dict,  # { "invite_code": "CHNG-XXXX" }
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    User pastes an invite code to join a chama.
    No chama_id needed — the code carries the context.
    """
    code = payload.get("invite_code", "").strip().upper()
    if not code:
        raise HTTPException(status_code=422, detail="Invite code is required")

    invite = db.query(ChamaInvite).filter(
        ChamaInvite.invite_code == code,
        ChamaInvite.method == InviteMethod.CODE,
    ).first()

    if not invite:
        raise HTTPException(status_code=404, detail="Invalid invite code")

    # Check expiry
    if invite.expires_at < datetime.now(timezone.utc):
        invite.status = InviteStatus.EXPIRED
        db.commit()
        raise HTTPException(status_code=400, detail="This invite code has expired")

    # Already a member?
    already = db.query(ChamaMember).filter(
        ChamaMember.chama_id == invite.chama_id,
        ChamaMember.user_id == current_user.id,
    ).first()
    if already:
        raise HTTPException(status_code=400, detail="You are already a member of this chama")

    # Add as member
    db.add(ChamaMember(
        chama_id=invite.chama_id,
        user_id=current_user.id,
        role=ChamaMemberRole.MEMBER,
    ))

    # Mark invite used — don't invalidate it, others can still use same code
    # (code invites are multi-use until expiry, like a WhatsApp group link)
    invite.status = InviteStatus.ACCEPTED
    invite.responded_at = datetime.now(timezone.utc)

    db.commit()

    chama = db.query(Chama).filter(Chama.id == invite.chama_id).first()
    return {
        "detail": f"Welcome to {chama.name}!",
        "chama_id": str(chama.id),
        "chama_name": chama.name,
    }


# ── REMOVE MEMBER ──────────────────────────────────────────────────────────────

@router.delete("/{chama_id}/members/{user_id}", status_code=204)
def remove_member(
    chama_id: UUID,
    user_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Admin removes a member. Owner cannot be removed."""
    chama = _assert_chama_admin(chama_id, current_user, db)

    member = db.query(ChamaMember).filter(
        ChamaMember.chama_id == chama_id,
        ChamaMember.user_id == user_id,
    ).first()
    if not member:
        raise HTTPException(status_code=404, detail="Member not found")
    if member.role == ChamaMemberRole.OWNER:
        raise HTTPException(status_code=400, detail="Cannot remove the chama owner")

    db.delete(member)
    db.commit()


# ── USER'S PENDING INVITES (notification inbox) ────────────────────────────────

@router.get("/me/invites")
def my_invites(
    status: Optional[str] = Query("pending"),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    GET /chamas/me/invites               → pending invites (default)
    GET /chamas/me/invites?status=all    → all invites
    """
    query = db.query(ChamaInvite).filter(
        ChamaInvite.user_id == current_user.id,
        ChamaInvite.method == InviteMethod.PHONE,
    )
    if status != "all":
        query = query.filter(ChamaInvite.status == InviteStatus.PENDING)

    invites = query.order_by(ChamaInvite.created_at.desc()).all()
    return [_build_invite_response(i, db) for i in invites]


# ── ACCEPT / DECLINE INVITE ────────────────────────────────────────────────────

@router.post("/me/invites/{invite_id}/accept")
def accept_invite(
    invite_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    invite = db.query(ChamaInvite).filter(
        ChamaInvite.id == invite_id,
        ChamaInvite.user_id == current_user.id,
        ChamaInvite.status == InviteStatus.PENDING,
    ).first()
    if not invite:
        raise HTTPException(status_code=404, detail="Invite not found")
    if invite.expires_at < datetime.now(timezone.utc):
        invite.status = InviteStatus.EXPIRED
        db.commit()
        raise HTTPException(status_code=400, detail="This invite has expired")

    # Already a member guard
    already = db.query(ChamaMember).filter(
        ChamaMember.chama_id == invite.chama_id,
        ChamaMember.user_id == current_user.id,
    ).first()
    if not already:
        db.add(ChamaMember(
            chama_id=invite.chama_id,
            user_id=current_user.id,
            role=ChamaMemberRole.MEMBER,
        ))

    invite.status = InviteStatus.ACCEPTED
    invite.responded_at = datetime.now(timezone.utc)
    db.commit()

    chama = db.query(Chama).filter(Chama.id == invite.chama_id).first()
    return {
        "detail": f"You joined {chama.name}",
        "chama_id": str(chama.id),
        "chama_name": chama.name,
    }


@router.post("/me/invites/{invite_id}/decline")
def decline_invite(
    invite_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    invite = db.query(ChamaInvite).filter(
        ChamaInvite.id == invite_id,
        ChamaInvite.user_id == current_user.id,
        ChamaInvite.status == InviteStatus.PENDING,
    ).first()
    if not invite:
        raise HTTPException(status_code=404, detail="Invite not found")

    invite.status = InviteStatus.DECLINED
    invite.responded_at = datetime.now(timezone.utc)
    db.commit()
    return {"detail": "Invite declined"}
