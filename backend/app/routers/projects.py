from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from typing import Optional
from uuid import UUID
import math

from app.database import get_db
from app.core.security import get_current_user
from app.models.models import (
    User, Project, ProjectMember, Team, TeamMember,
    MemberRole, ProjectVisibility, ContributionStatus,
)
from app.schemas.projects import (
    ProjectCreateRequest, ProjectUpdateRequest, ProjectResponse,
    ProjectListResponse, InviteMemberRequest, TeamCreateRequest, TeamResponse,
)

router = APIRouter(prefix="/projects", tags=["Projects"])


def _assert_project_access(project: Project, user: User, db: Session) -> None:
    """Raise 404 if user cannot see this project."""
    if project.visibility == ProjectVisibility.PUBLIC:
        return
    is_member = db.query(ProjectMember).filter(
        ProjectMember.project_id == project.id,
        ProjectMember.user_id == user.id,
    ).first()
    if not is_member:
        raise HTTPException(status_code=404, detail="Project not found")


def _assert_owner_or_admin(project: Project, user: User, db: Session) -> None:
    if str(project.owner_id) == str(user.id):
        return
    member = db.query(ProjectMember).filter(
        ProjectMember.project_id == project.id,
        ProjectMember.user_id == user.id,
        ProjectMember.role.in_([MemberRole.OWNER, MemberRole.ADMIN]),
    ).first()
    if not member:
        raise HTTPException(status_code=403, detail="Insufficient permissions")


# ── List & Search ──────────────────────────────────────────────────────────────

@router.get("", response_model=ProjectListResponse)
def list_projects(
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    search: Optional[str] = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    query = db.query(Project).filter(Project.visibility == ProjectVisibility.PUBLIC)
    if search:
        query = query.filter(Project.title.ilike(f"%{search}%"))

    total = query.count()
    projects = query.order_by(Project.created_at.desc()).offset((page - 1) * page_size).limit(page_size).all()

    return ProjectListResponse(
        items=[ProjectResponse.model_validate(p) for p in projects],
        total=total,
        page=page,
        pages=math.ceil(total / page_size) if total else 1,
    )


# ── Create ─────────────────────────────────────────────────────────────────────

@router.post("", response_model=ProjectResponse, status_code=201)
def create_project(
    payload: ProjectCreateRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    project = Project(owner_id=current_user.id, **payload.model_dump())
    db.add(project)
    db.flush()

    # Owner is automatically a member
    db.add(ProjectMember(project_id=project.id, user_id=current_user.id, role=MemberRole.OWNER))
    db.commit()
    db.refresh(project)
    return ProjectResponse.model_validate(project)


# ── Get single ────────────────────────────────────────────────────────────────

@router.get("/{project_id}", response_model=ProjectResponse)
def get_project(
    project_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    project = db.query(Project).filter(Project.id == project_id).first()
    if not project:
        raise HTTPException(status_code=404, detail="Project not found")
    _assert_project_access(project, current_user, db)
    return ProjectResponse.model_validate(project)


# ── Update ─────────────────────────────────────────────────────────────────────

@router.put("/{project_id}", response_model=ProjectResponse)
def update_project(
    project_id: UUID,
    payload: ProjectUpdateRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    project = db.query(Project).filter(Project.id == project_id).first()
    if not project:
        raise HTTPException(status_code=404, detail="Project not found")
    _assert_owner_or_admin(project, current_user, db)

    for field, value in payload.model_dump(exclude_unset=True).items():
        setattr(project, field, value)
    db.commit()
    db.refresh(project)
    return ProjectResponse.model_validate(project)


# ── Delete ─────────────────────────────────────────────────────────────────────

@router.delete("/{project_id}", status_code=204)
def delete_project(
    project_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    project = db.query(Project).filter(Project.id == project_id).first()
    if not project:
        raise HTTPException(status_code=404, detail="Project not found")
    if str(project.owner_id) != str(current_user.id):
        raise HTTPException(status_code=403, detail="Only the owner can delete a project")
    db.delete(project)
    db.commit()


# ── Contributors ───────────────────────────────────────────────────────────────

@router.get("/{project_id}/contributors")
def get_contributors(
    project_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    project = db.query(Project).filter(Project.id == project_id).first()
    if not project:
        raise HTTPException(status_code=404, detail="Project not found")
    _assert_project_access(project, current_user, db)

    successful = [c for c in project.contributions if c.status == ContributionStatus.SUCCESS]
    total_raised = sum(c.amount for c in successful)

    contributors = {}
    for c in successful:
        uid = str(c.user_id)
        if uid not in contributors:
            contributors[uid] = {"user_id": uid, "total": 0.0}
            if not project.is_anonymous:
                contributors[uid]["full_name"] = c.user.full_name
        contributors[uid]["total"] += c.amount

    result = []
    for uid, data in contributors.items():
        data["percentage"] = round((data["total"] / total_raised) * 100, 2) if total_raised else 0
        result.append(data)

    return sorted(result, key=lambda x: x["total"], reverse=True)


# ── Members (private projects) ─────────────────────────────────────────────────

@router.post("/{project_id}/members", status_code=201)
def invite_member(
    project_id: UUID,
    payload: InviteMemberRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    project = db.query(Project).filter(Project.id == project_id).first()
    if not project:
        raise HTTPException(status_code=404, detail="Project not found")
    _assert_owner_or_admin(project, current_user, db)

    user = None
    if payload.email:
        user = db.query(User).filter(User.email == payload.email).first()
    elif payload.phone:
        user = db.query(User).filter(User.phone == payload.phone).first()

    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    existing = db.query(ProjectMember).filter(
        ProjectMember.project_id == project_id,
        ProjectMember.user_id == user.id,
    ).first()
    if existing:
        raise HTTPException(status_code=400, detail="User is already a member")

    db.add(ProjectMember(
        project_id=project_id,
        user_id=user.id,
        role=MemberRole.MEMBER,
        invited_by=current_user.id,
    ))
    db.commit()
    return {"detail": f"{user.full_name} added to project"}


# ── Teams ──────────────────────────────────────────────────────────────────────

@router.post("/{project_id}/teams", response_model=TeamResponse, status_code=201)
def create_team(
    project_id: UUID,
    payload: TeamCreateRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    project = db.query(Project).filter(Project.id == project_id).first()
    if not project:
        raise HTTPException(status_code=404, detail="Project not found")
    _assert_project_access(project, current_user, db)

    team = Team(project_id=project_id, **payload.model_dump())
    db.add(team)
    db.flush()
    db.add(TeamMember(team_id=team.id, user_id=current_user.id, role=MemberRole.ADMIN))
    db.commit()
    db.refresh(team)
    return TeamResponse.model_validate(team)


@router.get("/{project_id}/teams", response_model=list[TeamResponse])
def list_teams(
    project_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    project = db.query(Project).filter(Project.id == project_id).first()
    if not project:
        raise HTTPException(status_code=404, detail="Project not found")
    _assert_project_access(project, current_user, db)
    return [TeamResponse.model_validate(t) for t in project.teams]


@router.post("/{project_id}/teams/{team_id}/join", status_code=200)
def join_team(
    project_id: UUID,
    team_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    team = db.query(Team).filter(Team.id == team_id, Team.project_id == project_id).first()
    if not team:
        raise HTTPException(status_code=404, detail="Team not found")

    existing = db.query(TeamMember).filter(
        TeamMember.team_id == team_id, TeamMember.user_id == current_user.id
    ).first()
    if existing:
        raise HTTPException(status_code=400, detail="Already in this team")

    db.add(TeamMember(team_id=team_id, user_id=current_user.id))
    db.commit()
    return {"detail": f"Joined team {team.name}"}
