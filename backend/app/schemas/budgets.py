from pydantic import BaseModel, field_validator
from typing import Optional, List
from uuid import UUID
from datetime import datetime
from app.models.models import BudgetType, BudgetCategoryType


# ── Budget Category ────────────────────────────────────────────────────────────

class BudgetCategoryCreate(BaseModel):
    category: BudgetCategoryType = BudgetCategoryType.OTHER
    custom_label: Optional[str] = None
    allocated_amount: float
    sort_order: int = 0

    @field_validator("allocated_amount")
    @classmethod
    def validate_amount(cls, v: float) -> float:
        if v < 0:
            raise ValueError("Allocated amount cannot be negative")
        return v


class BudgetCategoryUpdate(BaseModel):
    custom_label: Optional[str] = None
    allocated_amount: Optional[float] = None
    sort_order: Optional[int] = None


class BudgetExpenseResponse(BaseModel):
    id: UUID
    category_id: UUID
    description: str
    amount: float
    date: datetime
    created_at: datetime

    model_config = {"from_attributes": True}


class BudgetCategoryResponse(BaseModel):
    id: UUID
    budget_id: UUID
    category: BudgetCategoryType
    custom_label: Optional[str]
    label: str
    allocated_amount: float
    spent_amount: float
    remaining: float
    progress: float
    is_over_budget: bool
    sort_order: int
    expenses: List[BudgetExpenseResponse] = []

    model_config = {"from_attributes": True}


# ── Budget ─────────────────────────────────────────────────────────────────────

class BudgetCreateRequest(BaseModel):
    title: str
    type: BudgetType = BudgetType.PERSONAL
    total_income: float
    event_date: Optional[datetime] = None
    linked_chama_id: Optional[UUID] = None
    linked_chama_name: Optional[str] = None
    linked_project_id: Optional[UUID] = None
    linked_project_name: Optional[str] = None
    categories: List[BudgetCategoryCreate] = []

    @field_validator("title")
    @classmethod
    def validate_title(cls, v: str) -> str:
        if len(v.strip()) < 2:
            raise ValueError("Title must be at least 2 characters")
        return v.strip()

    @field_validator("total_income")
    @classmethod
    def validate_income(cls, v: float) -> float:
        if v < 0:
            raise ValueError("Total income cannot be negative")
        return v


class BudgetUpdateRequest(BaseModel):
    title: Optional[str] = None
    total_income: Optional[float] = None
    event_date: Optional[datetime] = None
    linked_chama_id: Optional[UUID] = None
    linked_chama_name: Optional[str] = None
    linked_project_id: Optional[UUID] = None
    linked_project_name: Optional[str] = None


class BudgetResponse(BaseModel):
    id: UUID
    user_id: UUID
    title: str
    type: BudgetType
    total_income: float
    currency: str
    total_allocated: float
    total_spent: float
    unallocated: float
    overall_progress: float
    event_date: Optional[datetime]
    linked_chama_id: Optional[UUID]
    linked_chama_name: Optional[str]
    linked_project_id: Optional[UUID]
    linked_project_name: Optional[str]
    categories: List[BudgetCategoryResponse] = []
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


class BudgetListResponse(BaseModel):
    items: List[BudgetResponse]
    total: int


# ── Expense ────────────────────────────────────────────────────────────────────

class ExpenseCreateRequest(BaseModel):
    description: str
    amount: float
    date: Optional[datetime] = None

    @field_validator("amount")
    @classmethod
    def validate_amount(cls, v: float) -> float:
        if v <= 0:
            raise ValueError("Expense amount must be greater than 0")
        return v

    @field_validator("description")
    @classmethod
    def validate_description(cls, v: str) -> str:
        if not v.strip():
            raise ValueError("Description is required")
        return v.strip()