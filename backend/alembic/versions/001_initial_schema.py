"""initial_schema — truthful baseline

Regenerated with `alembic revision --autogenerate` directly from the ORM
models (app/models/models.py) against an empty database, so it is
guaranteed to match what the application actually creates — verified with
`alembic check`.

The previous version of this migration described `teams` / `project_members`
/ a `projects.visibility` column that no longer exist anywhere in the
codebase, while `create_tables()` (Base.metadata.create_all()) silently
created the *real* schema on every boot. That meant `alembic upgrade head`
on a fresh database produced a schema the application could not run
against, and there was no migration history an operator could trust.
`create_tables()` has been removed from the application lifespan (see
app/database.py, app/main.py) — Alembic is now the only thing that touches
DDL. See docs/Changa_Engineering_audit.md, finding DB-01.

Revision ID: 001_initial
Revises:
Create Date: 2026-03-24
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "001_initial"
down_revision: Union[str, Sequence[str], None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table('users',
    sa.Column('id', sa.UUID(), nullable=False),
    sa.Column('email', sa.String(length=255), nullable=False),
    sa.Column('phone', sa.String(length=20), nullable=False),
    sa.Column('full_name', sa.String(length=255), nullable=False),
    sa.Column('hashed_password', sa.String(length=255), nullable=False),
    sa.Column('avatar_url', sa.String(length=500), nullable=True),
    sa.Column('is_active', sa.Boolean(), nullable=False),
    sa.Column('is_verified', sa.Boolean(), nullable=False),
    sa.Column('created_at', sa.DateTime(timezone=True), nullable=True),
    sa.Column('updated_at', sa.DateTime(timezone=True), nullable=True),
    sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_users_email'), 'users', ['email'], unique=True)
    op.create_index(op.f('ix_users_id'), 'users', ['id'], unique=False)
    op.create_index(op.f('ix_users_phone'), 'users', ['phone'], unique=True)
    op.create_table('chamas',
    sa.Column('id', sa.UUID(), nullable=False),
    sa.Column('owner_id', sa.UUID(), nullable=False),
    sa.Column('name', sa.String(length=255), nullable=False),
    sa.Column('description', sa.Text(), nullable=True),
    sa.Column('avatar_color', sa.String(length=7), nullable=True),
    sa.Column('invite_code', sa.String(length=16), nullable=False),
    sa.Column('is_active', sa.Boolean(), nullable=False),
    sa.Column('created_at', sa.DateTime(timezone=True), nullable=True),
    sa.Column('updated_at', sa.DateTime(timezone=True), nullable=True),
    sa.ForeignKeyConstraint(['owner_id'], ['users.id'], ),
    sa.PrimaryKeyConstraint('id'),
    sa.UniqueConstraint('invite_code')
    )
    op.create_index(op.f('ix_chamas_id'), 'chamas', ['id'], unique=False)
    op.create_index(op.f('ix_chamas_owner_id'), 'chamas', ['owner_id'], unique=False)
    op.create_table('refresh_tokens',
    sa.Column('id', sa.UUID(), nullable=False),
    sa.Column('user_id', sa.UUID(), nullable=False),
    sa.Column('token', sa.String(length=500), nullable=False),
    sa.Column('is_revoked', sa.Boolean(), nullable=False),
    sa.Column('created_at', sa.DateTime(timezone=True), nullable=True),
    sa.Column('expires_at', sa.DateTime(timezone=True), nullable=False),
    sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('id'),
    sa.UniqueConstraint('token')
    )
    op.create_index(op.f('ix_refresh_tokens_user_id'), 'refresh_tokens', ['user_id'], unique=False)
    op.create_table('chama_members',
    sa.Column('id', sa.UUID(), nullable=False),
    sa.Column('chama_id', sa.UUID(), nullable=False),
    sa.Column('user_id', sa.UUID(), nullable=False),
    sa.Column('role', sa.Enum('OWNER', 'ADMIN', 'MEMBER', name='chamamemberrole'), nullable=False),
    sa.Column('invited_by', sa.UUID(), nullable=True),
    sa.Column('joined_at', sa.DateTime(timezone=True), nullable=True),
    sa.ForeignKeyConstraint(['chama_id'], ['chamas.id'], ondelete='CASCADE'),
    sa.ForeignKeyConstraint(['invited_by'], ['users.id'], ),
    sa.ForeignKeyConstraint(['user_id'], ['users.id'], ),
    sa.PrimaryKeyConstraint('id'),
    sa.UniqueConstraint('chama_id', 'user_id', name='uq_chama_member')
    )
    op.create_index(op.f('ix_chama_members_chama_id'), 'chama_members', ['chama_id'], unique=False)
    op.create_index(op.f('ix_chama_members_user_id'), 'chama_members', ['user_id'], unique=False)
    op.create_table('projects',
    sa.Column('id', sa.UUID(), nullable=False),
    sa.Column('chama_id', sa.UUID(), nullable=False),
    sa.Column('owner_id', sa.UUID(), nullable=False),
    sa.Column('title', sa.String(length=255), nullable=False),
    sa.Column('description', sa.Text(), nullable=True),
    sa.Column('cover_image_url', sa.String(length=500), nullable=True),
    sa.Column('target_amount', sa.Float(), nullable=False),
    sa.Column('raised_amount', sa.Float(), nullable=False),
    sa.Column('currency', sa.String(length=3), nullable=False),
    sa.Column('status', sa.Enum('ACTIVE', 'COMPLETED', 'CANCELLED', 'PAUSED', name='projectstatus'), nullable=False),
    sa.Column('is_anonymous', sa.Boolean(), nullable=False),
    sa.Column('deadline', sa.DateTime(timezone=True), nullable=True),
    sa.Column('payment_type', sa.Enum('PAYBILL', 'TILL', 'POCHI', name='paymentaccounttype'), nullable=False),
    sa.Column('payment_number', sa.String(length=20), nullable=False),
    sa.Column('payment_name', sa.String(length=255), nullable=True),
    sa.Column('account_reference', sa.String(length=100), nullable=True),
    sa.Column('created_at', sa.DateTime(timezone=True), nullable=True),
    sa.Column('updated_at', sa.DateTime(timezone=True), nullable=True),
    sa.ForeignKeyConstraint(['chama_id'], ['chamas.id'], ondelete='CASCADE'),
    sa.ForeignKeyConstraint(['owner_id'], ['users.id'], ),
    sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_projects_chama_id'), 'projects', ['chama_id'], unique=False)
    op.create_index(op.f('ix_projects_id'), 'projects', ['id'], unique=False)
    op.create_index(op.f('ix_projects_owner_id'), 'projects', ['owner_id'], unique=False)
    op.create_table('budgets',
    sa.Column('id', sa.UUID(), nullable=False),
    sa.Column('user_id', sa.UUID(), nullable=False),
    sa.Column('title', sa.String(length=255), nullable=False),
    sa.Column('type', sa.Enum('PERSONAL', 'EVENT', 'CHAMA', name='budgettype'), nullable=False),
    sa.Column('total_income', sa.Float(), nullable=False),
    sa.Column('currency', sa.String(length=3), nullable=False),
    sa.Column('event_date', sa.DateTime(timezone=True), nullable=True),
    sa.Column('linked_chama_id', sa.UUID(), nullable=True),
    sa.Column('linked_chama_name', sa.String(length=255), nullable=True),
    sa.Column('linked_project_id', sa.UUID(), nullable=True),
    sa.Column('linked_project_name', sa.String(length=255), nullable=True),
    sa.Column('created_at', sa.DateTime(timezone=True), nullable=True),
    sa.Column('updated_at', sa.DateTime(timezone=True), nullable=True),
    sa.ForeignKeyConstraint(['linked_chama_id'], ['chamas.id'], ),
    sa.ForeignKeyConstraint(['linked_project_id'], ['projects.id'], ),
    sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_budgets_id'), 'budgets', ['id'], unique=False)
    op.create_index(op.f('ix_budgets_linked_chama_id'), 'budgets', ['linked_chama_id'], unique=False)
    op.create_index(op.f('ix_budgets_linked_project_id'), 'budgets', ['linked_project_id'], unique=False)
    op.create_index(op.f('ix_budgets_user_id'), 'budgets', ['user_id'], unique=False)
    op.create_table('contributions',
    sa.Column('id', sa.UUID(), nullable=False),
    sa.Column('project_id', sa.UUID(), nullable=False),
    sa.Column('user_id', sa.UUID(), nullable=False),
    sa.Column('amount', sa.Float(), nullable=False),
    sa.Column('currency', sa.String(length=3), nullable=False),
    sa.Column('provider', sa.Enum('MPESA', 'AIRTEL', name='paymentprovider'), nullable=False),
    sa.Column('phone', sa.String(length=20), nullable=False),
    sa.Column('reference', sa.String(length=100), nullable=False),
    sa.Column('provider_reference', sa.String(length=100), nullable=True),
    sa.Column('status', sa.Enum('PENDING', 'SUCCESS', 'FAILED', 'CANCELLED', name='contributionstatus'), nullable=False),
    sa.Column('failure_reason', sa.Text(), nullable=True),
    sa.Column('initiated_at', sa.DateTime(timezone=True), nullable=True),
    sa.Column('completed_at', sa.DateTime(timezone=True), nullable=True),
    sa.ForeignKeyConstraint(['project_id'], ['projects.id'], ),
    sa.ForeignKeyConstraint(['user_id'], ['users.id'], ),
    sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_contributions_id'), 'contributions', ['id'], unique=False)
    op.create_index(op.f('ix_contributions_project_id'), 'contributions', ['project_id'], unique=False)
    op.create_index(op.f('ix_contributions_reference'), 'contributions', ['reference'], unique=True)
    op.create_index(op.f('ix_contributions_user_id'), 'contributions', ['user_id'], unique=False)
    op.create_table('budget_categories',
    sa.Column('id', sa.UUID(), nullable=False),
    sa.Column('budget_id', sa.UUID(), nullable=False),
    sa.Column('category', sa.Enum('FOOD', 'TRANSPORT', 'RENT', 'UTILITIES', 'HEALTHCARE', 'EDUCATION', 'ENTERTAINMENT', 'CLOTHING', 'SAVINGS', 'VENUE', 'CATERING', 'DECORATION', 'PHOTOGRAPHY', 'MUSIC', 'GIFTS', 'CONTRIBUTION', 'OTHER', name='budgetcategorytype'), nullable=False),
    sa.Column('custom_label', sa.String(length=255), nullable=True),
    sa.Column('allocated_amount', sa.Float(), nullable=False),
    sa.Column('spent_amount', sa.Float(), nullable=False),
    sa.Column('sort_order', sa.Integer(), nullable=False),
    sa.Column('created_at', sa.DateTime(timezone=True), nullable=True),
    sa.ForeignKeyConstraint(['budget_id'], ['budgets.id'], ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_budget_categories_budget_id'), 'budget_categories', ['budget_id'], unique=False)
    op.create_index(op.f('ix_budget_categories_id'), 'budget_categories', ['id'], unique=False)
    op.create_table('budget_expenses',
    sa.Column('id', sa.UUID(), nullable=False),
    sa.Column('category_id', sa.UUID(), nullable=False),
    sa.Column('description', sa.String(length=500), nullable=False),
    sa.Column('amount', sa.Float(), nullable=False),
    sa.Column('date', sa.DateTime(timezone=True), nullable=False),
    sa.Column('created_at', sa.DateTime(timezone=True), nullable=True),
    sa.ForeignKeyConstraint(['category_id'], ['budget_categories.id'], ondelete='CASCADE'),
    sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_budget_expenses_category_id'), 'budget_expenses', ['category_id'], unique=False)
    op.create_index(op.f('ix_budget_expenses_id'), 'budget_expenses', ['id'], unique=False)


def downgrade() -> None:
    op.drop_index(op.f('ix_budget_expenses_id'), table_name='budget_expenses')
    op.drop_index(op.f('ix_budget_expenses_category_id'), table_name='budget_expenses')
    op.drop_table('budget_expenses')
    op.drop_index(op.f('ix_budget_categories_id'), table_name='budget_categories')
    op.drop_index(op.f('ix_budget_categories_budget_id'), table_name='budget_categories')
    op.drop_table('budget_categories')
    op.drop_index(op.f('ix_contributions_user_id'), table_name='contributions')
    op.drop_index(op.f('ix_contributions_reference'), table_name='contributions')
    op.drop_index(op.f('ix_contributions_project_id'), table_name='contributions')
    op.drop_index(op.f('ix_contributions_id'), table_name='contributions')
    op.drop_table('contributions')
    op.drop_index(op.f('ix_budgets_user_id'), table_name='budgets')
    op.drop_index(op.f('ix_budgets_linked_project_id'), table_name='budgets')
    op.drop_index(op.f('ix_budgets_linked_chama_id'), table_name='budgets')
    op.drop_index(op.f('ix_budgets_id'), table_name='budgets')
    op.drop_table('budgets')
    op.drop_index(op.f('ix_projects_owner_id'), table_name='projects')
    op.drop_index(op.f('ix_projects_id'), table_name='projects')
    op.drop_index(op.f('ix_projects_chama_id'), table_name='projects')
    op.drop_table('projects')
    op.drop_index(op.f('ix_chama_members_user_id'), table_name='chama_members')
    op.drop_index(op.f('ix_chama_members_chama_id'), table_name='chama_members')
    op.drop_table('chama_members')
    op.drop_index(op.f('ix_refresh_tokens_user_id'), table_name='refresh_tokens')
    op.drop_table('refresh_tokens')
    op.drop_index(op.f('ix_chamas_owner_id'), table_name='chamas')
    op.drop_index(op.f('ix_chamas_id'), table_name='chamas')
    op.drop_table('chamas')
    op.drop_index(op.f('ix_users_phone'), table_name='users')
    op.drop_index(op.f('ix_users_id'), table_name='users')
    op.drop_index(op.f('ix_users_email'), table_name='users')
    op.drop_table('users')

    for enum_name in (
        "budgetcategorytype", "budgettype", "contributionstatus",
        "paymentprovider", "paymentaccounttype", "projectstatus", "chamamemberrole",
    ):
        sa.Enum(name=enum_name).drop(op.get_bind(), checkfirst=True)
