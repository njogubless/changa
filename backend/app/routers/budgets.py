from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from uuid import UUID
from datetime import datetime, timezone

from app.database import get_db
from app.core.security import get_current_user
from app.models.models import (
    User, Budget, BudgetCategory, BudgetExpense, utcnow,
)
from app.schemas.budgets import (
    BudgetCreateRequest, BudgetUpdateRequest, BudgetResponse,
    BudgetListResponse, BudgetCategoryCreate, BudgetCategoryUpdate,
    BudgetCategoryResponse, ExpenseCreateRequest, BudgetExpenseResponse,
)

router = APIRouter(prefix="/budgets", tags=["Budgets"])



def _get_budget_or_404(budget_id: UUID, user: User, db: Session) -> Budget:
    budget = db.query(Budget).filter(
        Budget.id == budget_id,
        Budget.user_id == user.id,
    ).first()
    if not budget:
        raise HTTPException(status_code=404, detail="Budget not found")
    return budget


def _get_category_or_404(
    budget: Budget, category_id: UUID
) -> BudgetCategory:
    category = next(
        (c for c in budget.categories if str(c.id) == str(category_id)),
        None,
    )
    if not category:
        raise HTTPException(status_code=404, detail="Category not found")
    return category



@router.get("", response_model=BudgetListResponse)
def list_budgets(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    budgets = (
        db.query(Budget)
        .filter(Budget.user_id == current_user.id)
        .order_by(Budget.created_at.desc())
        .all()
    )
    return BudgetListResponse(
        items=[BudgetResponse.model_validate(b) for b in budgets],
        total=len(budgets),
    )


@router.post("", response_model=BudgetResponse, status_code=201)
def create_budget(
    payload: BudgetCreateRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    budget = Budget(
        user_id=current_user.id,
        title=payload.title,
        type=payload.type,
        total_income=payload.total_income,
        event_date=payload.event_date,
        linked_chama_id=payload.linked_chama_id,
        linked_chama_name=payload.linked_chama_name,
        linked_project_id=payload.linked_project_id,
        linked_project_name=payload.linked_project_name,
    )
    db.add(budget)
    db.flush()

    
    for i, cat in enumerate(payload.categories):
        db.add(BudgetCategory(
            budget_id=budget.id,
            category=cat.category,
            custom_label=cat.custom_label,
            allocated_amount=cat.allocated_amount,
            sort_order=cat.sort_order or i,
        ))

    db.commit()
    db.refresh(budget)
    return BudgetResponse.model_validate(budget)


@router.get("/{budget_id}", response_model=BudgetResponse)
def get_budget(
    budget_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    budget = _get_budget_or_404(budget_id, current_user, db)
    return BudgetResponse.model_validate(budget)


@router.put("/{budget_id}", response_model=BudgetResponse)
def update_budget(
    budget_id: UUID,
    payload: BudgetUpdateRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    budget = _get_budget_or_404(budget_id, current_user, db)

    for field, value in payload.model_dump(exclude_unset=True).items():
        setattr(budget, field, value)

    db.commit()
    db.refresh(budget)
    return BudgetResponse.model_validate(budget)


@router.delete("/{budget_id}", status_code=204)
def delete_budget(
    budget_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    budget = _get_budget_or_404(budget_id, current_user, db)
    db.delete(budget)
    db.commit()




@router.post("/{budget_id}/categories", response_model=BudgetCategoryResponse, status_code=201)
def add_category(
    budget_id: UUID,
    payload: BudgetCategoryCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    budget = _get_budget_or_404(budget_id, current_user, db)

    category = BudgetCategory(
        budget_id=budget.id,
        category=payload.category,
        custom_label=payload.custom_label,
        allocated_amount=payload.allocated_amount,
        sort_order=payload.sort_order or len(budget.categories),
    )
    db.add(category)
    db.commit()
    db.refresh(category)
    return BudgetCategoryResponse.model_validate(category)


@router.put("/{budget_id}/categories/{category_id}", response_model=BudgetCategoryResponse)
def update_category(
    budget_id: UUID,
    category_id: UUID,
    payload: BudgetCategoryUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    budget = _get_budget_or_404(budget_id, current_user, db)
    category = _get_category_or_404(budget, category_id)

    for field, value in payload.model_dump(exclude_unset=True).items():
        setattr(category, field, value)

    db.commit()
    db.refresh(category)
    return BudgetCategoryResponse.model_validate(category)


@router.delete("/{budget_id}/categories/{category_id}", status_code=204)
def delete_category(
    budget_id: UUID,
    category_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    budget = _get_budget_or_404(budget_id, current_user, db)
    category = _get_category_or_404(budget, category_id)
    db.delete(category)
    db.commit()




@router.post(
    "/{budget_id}/categories/{category_id}/expenses",
    response_model=BudgetExpenseResponse,
    status_code=201,
)
def add_expense(
    budget_id: UUID,
    category_id: UUID,
    payload: ExpenseCreateRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    budget = _get_budget_or_404(budget_id, current_user, db)
    category = _get_category_or_404(budget, category_id)

    expense = BudgetExpense(
        category_id=category.id,
        description=payload.description,
        amount=payload.amount,
        date=payload.date or datetime.now(timezone.utc),
    )
    db.add(expense)

    
    category.spent_amount += payload.amount

    db.commit()
    db.refresh(expense)
    return BudgetExpenseResponse.model_validate(expense)


@router.delete(
    "/{budget_id}/categories/{category_id}/expenses/{expense_id}",
    status_code=204,
)
def delete_expense(
    budget_id: UUID,
    category_id: UUID,
    expense_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    budget = _get_budget_or_404(budget_id, current_user, db)
    category = _get_category_or_404(budget, category_id)

    expense = next(
        (e for e in category.expenses if str(e.id) == str(expense_id)),
        None,
    )
    if not expense:
        raise HTTPException(status_code=404, detail="Expense not found")

    
    category.spent_amount = max(0.0, category.spent_amount - expense.amount)
    db.delete(expense)
    db.commit()




@router.get("/{budget_id}/summary")
def get_budget_summary(
    budget_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Quick summary without full expense lists — for list views."""
    budget = _get_budget_or_404(budget_id, current_user, db)
    return {
        "id": str(budget.id),
        "title": budget.title,
        "type": budget.type,
        "total_income": budget.total_income,
        "total_allocated": budget.total_allocated,
        "total_spent": budget.total_spent,
        "unallocated": budget.unallocated,
        "overall_progress": budget.overall_progress,
        "category_count": len(budget.categories),
        "is_over_budget": budget.total_spent > budget.total_allocated,
        "created_at": budget.created_at,
    }