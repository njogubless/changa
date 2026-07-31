"""payment_outbox — transactional outbox and reconciliation bookkeeping (PAY-03)

The request handler committed the contribution row and then awaited the
STK push inline: if the process died between the commit and the push, the
contribution was PENDING forever with no prompt ever sent; if the push
actually succeeded but the response was lost, the code marked the
contribution FAILED while the customer's phone was showing a live PIN
prompt. `outbox_messages` is written in the *same* transaction as the
contribution insert (see routers/payments.py), so the two can never be
split by a mid-flight crash. `contributions.push_attempts` /
`reconcile_attempts` bound the outbox worker's retries and the
reconciliation sweep's polling so a stuck contribution escalates instead
of being retried forever (see app/workers/payment_worker.py).

See docs/Changa_Engineering_audit.md, finding PAY-03.

Revision ID: 006_payment_outbox
Revises: 005_contribution_idempotency
Create Date: 2026-07-31
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "006_payment_outbox"
down_revision: Union[str, Sequence[str], None] = "005_contribution_idempotency"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table('outbox_messages',
    sa.Column('id', sa.UUID(), nullable=False),
    sa.Column('topic', sa.String(length=50), nullable=False),
    sa.Column('payload', sa.Text(), nullable=False),
    sa.Column('status', sa.Enum('PENDING', 'PROCESSING', 'DONE', 'FAILED', name='outboxstatus'), nullable=False),
    sa.Column('attempts', sa.Integer(), nullable=False),
    sa.Column('last_error', sa.String(length=255), nullable=True),
    sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
    sa.Column('processed_at', sa.DateTime(timezone=True), nullable=True),
    sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_outbox_messages_id'), 'outbox_messages', ['id'], unique=False)
    op.create_index('ix_outbox_status_created', 'outbox_messages', ['status', 'created_at'], unique=False)
    # server_default so this is safe to run against a table that already
    # has rows, not just an empty dev database.
    op.add_column('contributions', sa.Column('push_attempts', sa.Integer(), nullable=False, server_default='0'))
    op.add_column('contributions', sa.Column('reconcile_attempts', sa.Integer(), nullable=False, server_default='0'))


def downgrade() -> None:
    op.drop_column('contributions', 'reconcile_attempts')
    op.drop_column('contributions', 'push_attempts')
    op.drop_index('ix_outbox_status_created', table_name='outbox_messages')
    op.drop_index(op.f('ix_outbox_messages_id'), table_name='outbox_messages')
    op.drop_table('outbox_messages')
