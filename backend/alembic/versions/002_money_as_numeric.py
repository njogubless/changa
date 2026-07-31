"""money_as_numeric — exact decimal storage for every monetary column

Every monetary column in the schema was Float (Postgres DOUBLE PRECISION).
IEEE-754 doubles cannot represent most decimal fractions exactly, so
`raised_amount += amount` accumulated representation error across
contributions in a way that is not reproducible across summation order —
an unreconcilable-balance defect on a platform that moves real money.

This is a schema-only migration (no separate backfill/verify step): the
application has not yet processed live funds (see
docs/Changa_Engineering_audit.md, finding FIN-01), so there is no existing
financial history that a straight column-type change could put at risk.
`USING ROUND(... ::numeric, 2)` rounds any stray float precision noise to
the cent on the way in.

Revision ID: 002_money_as_numeric
Revises: 001_initial
Create Date: 2026-07-31
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "002_money_as_numeric"
down_revision: Union[str, Sequence[str], None] = "001_initial"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

_COLUMNS = [
    ("budget_categories", "allocated_amount"),
    ("budget_categories", "spent_amount"),
    ("budget_expenses", "amount"),
    ("budgets", "total_income"),
    ("contributions", "amount"),
    ("projects", "target_amount"),
    ("projects", "raised_amount"),
]


def upgrade() -> None:
    for table, column in _COLUMNS:
        op.alter_column(
            table, column,
            existing_type=sa.DOUBLE_PRECISION(precision=53),
            type_=sa.Numeric(precision=14, scale=2),
            existing_nullable=False,
            postgresql_using=f"ROUND({column}::numeric, 2)",
        )


def downgrade() -> None:
    for table, column in reversed(_COLUMNS):
        op.alter_column(
            table, column,
            existing_type=sa.Numeric(precision=14, scale=2),
            type_=sa.DOUBLE_PRECISION(precision=53),
            existing_nullable=False,
        )
