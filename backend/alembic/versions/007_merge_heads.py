"""merge_heads — join the SEC/REG and FIN/PAY migration branches

Revision ID: 007_merge_heads
Revises: 003_audit_compliance, 006_payment_outbox
Create Date: 2026-10-10

The SEC-01 → REG-01 branch (002_token_security → 003_audit_compliance) and
the FIN-01 → PAY-03 branch (002_money_as_numeric → … → 006_payment_outbox)
were both cut from 001_initial and merged into main separately, leaving two
Alembic heads. With two heads `alembic upgrade head` refuses to run and
`verify_schema_at_head()` raises at startup, so neither a fresh deploy nor
the API could come up.

The two branches touch disjoint tables (refresh_tokens / revoked_access_tokens
/ users.tokens_valid_after / audit_events / kyc_profiles / consent_records vs.
money columns / ledger_entries / provider_events / contributions / outbox_messages),
so this revision only joins the graph — it has no schema operations. Verified
with `alembic upgrade head` on an empty database followed by `alembic check`
reporting no drift against the models.
"""
from typing import Sequence, Union

revision: str = "007_merge_heads"
down_revision: Union[str, Sequence[str], None] = ("003_audit_compliance", "006_payment_outbox")
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    pass


def downgrade() -> None:
    pass
