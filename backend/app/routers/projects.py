from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from uuid import UUID

from app.database import get_db
from app.core.security import get_current_user
from app.models.models import (
    User, Project, ChamaMember, ContributionStatus,
)
from app.schemas.projects import (
    ProjectUpdateRequest, ProjectResponse,
)

router = APIRouter(prefix="/projects", tags=["Projects"])



def _get_project_or_404(project_id: UUID, db: Session) -> Project:
    project = db.query(Project).filter(Project.id == project_id).first()
    if not project:
        raise HTTPException(status_code=404, detail="Project not found")
    return project


def _assert_chama_member(project: Project, user: User, db: Session) -> None:
    """Raise 404 if user is not a member of the chama that owns this project."""
    is_member = db.query(ChamaMember).filter(
        ChamaMember.chama_id == project.chama_id,
        ChamaMember.user_id == user.id,
    ).first()
    if not is_member:
        
        raise HTTPException(status_code=404, detail="Project not found")


def _assert_owner(project: Project, user: User) -> None:
    if str(project.owner_id) != str(user.id):
        raise HTTPException(status_code=403, detail="Only the project owner can do this")




@router.get("/{project_id}", response_model=ProjectResponse)
def get_project(
    project_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    project = _get_project_or_404(project_id, db)
    _assert_chama_member(project, current_user, db)
    return ProjectResponse.model_validate(project)




@router.put("/{project_id}", response_model=ProjectResponse)
def update_project(
    project_id: UUID,
    payload: ProjectUpdateRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    project = _get_project_or_404(project_id, db)
    _assert_chama_member(project, current_user, db)
    _assert_owner(project, current_user)

    for field, value in payload.model_dump(exclude_unset=True).items():
        setattr(project, field, value)
    db.commit()
    db.refresh(project)
    return ProjectResponse.model_validate(project)




@router.delete("/{project_id}", status_code=204)
def delete_project(
    project_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    project = _get_project_or_404(project_id, db)
    _assert_chama_member(project, current_user, db)
    _assert_owner(project, current_user)

    db.delete(project)
    db.commit()




@router.get("/{project_id}/contributors")
def get_contributors(
    project_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    project = _get_project_or_404(project_id, db)
    _assert_chama_member(project, current_user, db)

    successful = [
        c for c in project.contributions
        if c.status == ContributionStatus.SUCCESS
    ]
    total_raised = sum(c.amount for c in successful)

    contributors: dict = {}
    for c in successful:
        uid = str(c.user_id)
        if uid not in contributors:
            contributors[uid] = {"user_id": uid, "total": 0.0}
            if not project.is_anonymous:
                contributors[uid]["full_name"] = c.user.full_name
        contributors[uid]["total"] += c.amount

    result = []
    for uid, data in contributors.items():
        data["percentage"] = (
            round((data["total"] / total_raised) * 100, 2) if total_raised else 0
        )
        result.append(data)

    return sorted(result, key=lambda x: x["total"], reverse=True)