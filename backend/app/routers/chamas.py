from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from uuid import UUID

from app.database import get_db
from app.core.security import get_current_user
from app.models.models import (
    User, Chama, ChamaMember, Project,
    ChamaMemberRole, ProjectStatus,
)
from app.schemas.chamas import (
    ChamaCreateRequest, ChamaUpdateRequest, JoinChamaRequest,
    ChamaResponse, ChamaDetailResponse, ChamaListResponse,
    ChamaMemberResponse,
)
from app.schemas.projects import (
    ProjectCreateRequest, ProjectResponse, ProjectListResponse,
)
import math

router = APIRouter(prefix="/chamas", tags=["Chamas"])


# ── Helpers ────────────────────────────────────────────────────────────────────

def _get_chama_or_404(chama_id: UUID, db: Session) -> Chama:
    chama = db.query(Chama).filter(Chama.id == chama_id).first()
    if not chama:
        raise HTTPException(status_code=404, detail="Chama not found")
    return chama


def _assert_member(chama: Chama, user: User, db: Session) -> ChamaMember:
    """Raise 403 if user is not a member of this chama."""
    member = db.query(ChamaMember).filter(
        ChamaMember.chama_id == chama.id,
        ChamaMember.user_id == user.id,
    ).first()
    if not member:
        raise HTTPException(status_code=403, detail="You are not a member of this Chama")
    return member


def _assert_owner(chama: Chama, user: User) -> None:
    """Raise 403 if user is not the chama owner."""
    if str(chama.owner_id) != str(user.id):
        raise HTTPException(status_code=403, detail="Only the Chama owner can do this")


def _member_response(member: ChamaMember) -> ChamaMemberResponse:
    return ChamaMemberResponse(
        user_id=member.user_id,
        full_name=member.user.full_name,
        email=member.user.email,
        role=member.role,
        joined_at=member.joined_at,
    )


# ── Create chama ───────────────────────────────────────────────────────────────

@router.post("", response_model=ChamaResponse, status_code=201)
def create_chama(
    payload: ChamaCreateRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    chama = Chama(
        owner_id=current_user.id,
        name=payload.name,
        description=payload.description,
        avatar_color=payload.avatar_color or "#1B4332",
    )
    db.add(chama)
    db.flush()

    # Creator is automatically owner member
    db.add(ChamaMember(
        chama_id=chama.id,
        user_id=current_user.id,
        role=ChamaMemberRole.OWNER,
    ))
    db.commit()
    db.refresh(chama)
    return ChamaResponse.model_validate(chama)


# ── List my chamas ─────────────────────────────────────────────────────────────

@router.get("", response_model=ChamaListResponse)
def list_my_chamas(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    memberships = db.query(ChamaMember).filter(
        ChamaMember.user_id == current_user.id,
    ).all()

    chamas = [m.chama for m in memberships if m.chama.is_active]
    return ChamaListResponse(
        items=[ChamaResponse.model_validate(c) for c in chamas],
        total=len(chamas),
    )


# ── Get chama detail ───────────────────────────────────────────────────────────

@router.get("/{chama_id}", response_model=ChamaDetailResponse)
def get_chama(
    chama_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    chama = _get_chama_or_404(chama_id, db)
    _assert_member(chama, current_user, db)

    return ChamaDetailResponse(
        id=chama.id,
        owner_id=chama.owner_id,
        name=chama.name,
        description=chama.description,
        avatar_color=chama.avatar_color,
        invite_code=chama.invite_code,
        is_active=chama.is_active,
        member_count=chama.member_count,
        active_project_count=chama.active_project_count,
        created_at=chama.created_at,
        members=[_member_response(m) for m in chama.members],
    )


# ── Update chama ───────────────────────────────────────────────────────────────

@router.put("/{chama_id}", response_model=ChamaResponse)
def update_chama(
    chama_id: UUID,
    payload: ChamaUpdateRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    chama = _get_chama_or_404(chama_id, db)
    _assert_owner(chama, current_user)

    for field, value in payload.model_dump(exclude_unset=True).items():
        setattr(chama, field, value)
    db.commit()
    db.refresh(chama)
    return ChamaResponse.model_validate(chama)


# ── Join chama via invite code ─────────────────────────────────────────────────

@router.post("/join", response_model=ChamaResponse, status_code=200)
def join_chama(
    payload: JoinChamaRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    chama = db.query(Chama).filter(
        Chama.invite_code == payload.invite_code,
        Chama.is_active == True,
    ).first()
    if not chama:
        raise HTTPException(status_code=404, detail="Invalid invite code")

    # Check if already a member
    existing = db.query(ChamaMember).filter(
        ChamaMember.chama_id == chama.id,
        ChamaMember.user_id == current_user.id,
    ).first()
    if existing:
        raise HTTPException(status_code=400, detail="You are already a member of this Chama")

    db.add(ChamaMember(
        chama_id=chama.id,
        user_id=current_user.id,
        role=ChamaMemberRole.MEMBER,
    ))
    db.commit()
    db.refresh(chama)
    return ChamaResponse.model_validate(chama)


# ── Leave chama ────────────────────────────────────────────────────────────────

@router.post("/{chama_id}/leave", status_code=200)
def leave_chama(
    chama_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    chama = _get_chama_or_404(chama_id, db)

    if str(chama.owner_id) == str(current_user.id):
        raise HTTPException(
            status_code=400,
            detail="Owner cannot leave. Transfer ownership or delete the Chama."
        )

    member = _assert_member(chama, current_user, db)
    db.delete(member)
    db.commit()
    return {"detail": f"You have left {chama.name}"}


# ── List members ───────────────────────────────────────────────────────────────

@router.get("/{chama_id}/members", response_model=list[ChamaMemberResponse])
def list_members(
    chama_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    chama = _get_chama_or_404(chama_id, db)
    _assert_member(chama, current_user, db)
    return [_member_response(m) for m in chama.members]


# ── Remove a member (owner only) ───────────────────────────────────────────────

@router.delete("/{chama_id}/members/{user_id}", status_code=200)
def remove_member(
    chama_id: UUID,
    user_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    chama = _get_chama_or_404(chama_id, db)
    _assert_owner(chama, current_user)

    if str(user_id) == str(current_user.id):
        raise HTTPException(status_code=400, detail="Cannot remove yourself")

    member = db.query(ChamaMember).filter(
        ChamaMember.chama_id == chama_id,
        ChamaMember.user_id == user_id,
    ).first()
    if not member:
        raise HTTPException(status_code=404, detail="Member not found")

    db.delete(member)
    db.commit()
    return {"detail": "Member removed"}


# ── Regenerate invite code (owner only) ────────────────────────────────────────

@router.post("/{chama_id}/regenerate-code", response_model=ChamaResponse)
def regenerate_invite_code(
    chama_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    from app.models.models import generate_invite_code
    chama = _get_chama_or_404(chama_id, db)
    _assert_owner(chama, current_user)

    chama.invite_code = generate_invite_code()
    db.commit()
    db.refresh(chama)
    return ChamaResponse.model_validate(chama)


# ── List projects in chama ─────────────────────────────────────────────────────

@router.get("/{chama_id}/projects", response_model=ProjectListResponse)
def list_chama_projects(
    chama_id: UUID,
    page: int = 1,
    page_size: int = 20,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    chama = _get_chama_or_404(chama_id, db)
    _assert_member(chama, current_user, db)

    query = db.query(Project).filter(Project.chama_id == chama_id)
    total = query.count()
    projects = (
        query.order_by(Project.created_at.desc())
        .offset((page - 1) * page_size)
        .limit(page_size)
        .all()
    )

    return ProjectListResponse(
        items=[ProjectResponse.model_validate(p) for p in projects],
        total=total,
        page=page,
        pages=math.ceil(total / page_size) if total else 1,
    )


# ── Create project inside chama (owner only) ───────────────────────────────────

@router.post("/{chama_id}/projects", response_model=ProjectResponse, status_code=201)
def create_chama_project(
    chama_id: UUID,
    payload: ProjectCreateRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    chama = _get_chama_or_404(chama_id, db)
    _assert_owner(chama, current_user)

    project = Project(
        chama_id=chama_id,
        owner_id=current_user.id,
        **payload.model_dump(),
    )
    db.add(project)
    db.commit()
    db.refresh(project)
    return ProjectResponse.model_validate(project)