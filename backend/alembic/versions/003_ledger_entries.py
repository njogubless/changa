"""ledger_entries — append-only source of truth for project balances

`Project.raised_amount` was mutated with `contribution.project.raised_amount
+= contribution.amount` — an unlocked Python-side read-modify-write with no
row lock and no atomic SQL update. Two callbacks for the same project that
interleave both read the same starting value and the second overwrites the
first: a lost update, and since raised_amount was the *only* record of the
total, there was no way to detect or repair the drift once it happened.

`ledger_entries` is now the single source of truth: a successful
contribution appends one CREDIT row (enforced unique per
(contribution_id, direction) so a replayed callback can't double-credit),
corrections append a REVERSAL row, and `raised_amount` is a projection kept
in sync by an atomic SQL UPDATE in the same transaction as the ledger
insert (see app/services/ledger_service.py) — never a Python `+=`.
`ledger_service.find_ledger_divergence()` recomputes every project's total
from this table and returns any row where the projection has drifted; wire
it to a scheduled job once the worker tier exists (PAY-03).

See docs/Changa_Engineering_audit.md, finding FIN-02.

Revision ID: 003_ledger_entries
Revises: 002_money_as_numeric
Create Date: 2026-07-31
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "003_ledger_entries"
down_revision: Union[str, Sequence[str], None] = "002_money_as_numeric"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table('ledger_entries',
    sa.Column('id', sa.UUID(), nullable=False),
    sa.Column('project_id', sa.UUID(), nullable=False),
    sa.Column('contribution_id', sa.UUID(), nullable=False),
    sa.Column('direction', sa.Enum('CREDIT', 'REVERSAL', name='ledgerdirection'), nullable=False),
    sa.Column('amount', sa.Numeric(precision=14, scale=2), nullable=False),
    sa.Column('currency', sa.String(length=3), nullable=False),
    sa.Column('reverses_id', sa.UUID(), nullable=True),
    sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
    sa.CheckConstraint('amount > 0', name='ck_ledger_amount_positive'),
    sa.ForeignKeyConstraint(['contribution_id'], ['contributions.id'], ),
    sa.ForeignKeyConstraint(['project_id'], ['projects.id'], ),
    sa.ForeignKeyConstraint(['reverses_id'], ['ledger_entries.id'], ),
    sa.PrimaryKeyConstraint('id'),
    sa.UniqueConstraint('contribution_id', 'direction', name='uq_ledger_contribution_direction')
    )
    op.create_index(op.f('ix_ledger_entries_id'), 'ledger_entries', ['id'], unique=False)
    op.create_index(op.f('ix_ledger_entries_project_id'), 'ledger_entries', ['project_id'], unique=False)
    op.create_index('ix_ledger_project_created', 'ledger_entries', ['project_id', 'created_at'], unique=False)


def downgrade() -> None:
    op.drop_index('ix_ledger_project_created', table_name='ledger_entries')
    op.drop_index(op.f('ix_ledger_entries_project_id'), table_name='ledger_entries')
    op.drop_index(op.f('ix_ledger_entries_id'), table_name='ledger_entries')
    op.drop_table('ledger_entries')
    # ### end Alembic commands ###
