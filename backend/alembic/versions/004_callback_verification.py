"""callback_verification — persist raw callbacks, verify via provider status

Payment callbacks were a plain public route with no signature verification,
no source-IP allowlist and no shared secret: the only thing standing
between an attacker and a forged "payment succeeded" event was knowledge
of a contribution's reference, which is returned to the payer in the 201
response and therefore never actually secret.

- provider_events: every raw callback body, persisted unconditionally
  before any decision logic runs — so a forged attempt is forensically
  visible even though it is never acted on.
- contributions.checkout_request_id: the handle used to query Safaricom
  server-to-server for a push's authoritative status. Deliberately never
  returned to the client (unlike `reference`), so it can't become another
  forgeable lookup key.

See docs/Changa_Engineering_audit.md, finding PAY-01.

Revision ID: 004_callback_verification
Revises: 003_ledger_entries
Create Date: 2026-07-31
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "004_callback_verification"
down_revision: Union[str, Sequence[str], None] = "003_ledger_entries"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table('provider_events',
    sa.Column('id', sa.UUID(), nullable=False),
    sa.Column('provider', sa.Enum('MPESA', 'AIRTEL', name='paymentprovider'), nullable=False),
    sa.Column('reference', sa.String(length=100), nullable=True),
    sa.Column('raw_body', sa.Text(), nullable=False),
    sa.Column('verified', sa.Boolean(), nullable=False),
    sa.Column('rejection_reason', sa.String(length=100), nullable=True),
    sa.Column('received_at', sa.DateTime(timezone=True), nullable=False),
    sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_provider_events_id'), 'provider_events', ['id'], unique=False)
    op.create_index(op.f('ix_provider_events_reference'), 'provider_events', ['reference'], unique=False)
    op.add_column('contributions', sa.Column('checkout_request_id', sa.String(length=100), nullable=True))
    op.create_index(op.f('ix_contributions_checkout_request_id'), 'contributions', ['checkout_request_id'], unique=False)


def downgrade() -> None:
    op.drop_index(op.f('ix_contributions_checkout_request_id'), table_name='contributions')
    op.drop_column('contributions', 'checkout_request_id')
    op.drop_index(op.f('ix_provider_events_reference'), table_name='provider_events')
    op.drop_index(op.f('ix_provider_events_id'), table_name='provider_events')
    op.drop_table('provider_events')
