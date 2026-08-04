"""token_security — hashed, rotating refresh tokens; revocable access tokens (SEC-01)

The full refresh JWT was written verbatim into `refresh_tokens.token` —
read access to this table (a backup, a replica, a logged query, a SQL
injection anywhere else in the app) was immediate, silent account
takeover for every user with an active session. Access tokens carried no
`jti`, so logout, password change and admin-disable were all cosmetic: a
token kept working for its full lifetime regardless.

This migration deletes every existing refresh token — there is no way to
retrofit `family_id` (rotation-chain grouping) onto sessions that were
never issued with one, and a plaintext token in this table has already
been exposed to anything with read access to it, so it should not be
trusted going forward regardless. This forces every user to log in again
on the next deploy; there is no live production traffic yet to disrupt
(see docs/Changa_Engineering_audit.md's scope note), so this is the
right trade at this point rather than a compatibility shim.

Revision ID: 002_token_security
Revises: 001_initial
Create Date: 2026-07-31
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "002_token_security"
down_revision: Union[str, Sequence[str], None] = "001_initial"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table('revoked_access_tokens',
    sa.Column('jti', sa.String(length=36), nullable=False),
    sa.Column('expires_at', sa.DateTime(timezone=True), nullable=False),
    sa.Column('revoked_at', sa.DateTime(timezone=True), nullable=False),
    sa.PrimaryKeyConstraint('jti')
    )

    # Every existing session is invalidated — see the module docstring.
    op.execute("DELETE FROM refresh_tokens")

    op.add_column('refresh_tokens', sa.Column('token_hash', sa.String(length=64), nullable=False))
    op.add_column('refresh_tokens', sa.Column('family_id', sa.UUID(), nullable=False))
    op.add_column('refresh_tokens', sa.Column('consumed_at', sa.DateTime(timezone=True), nullable=True))
    op.add_column('refresh_tokens', sa.Column('revoked_at', sa.DateTime(timezone=True), nullable=True))
    op.add_column('refresh_tokens', sa.Column('revoked_reason', sa.String(length=40), nullable=True))
    op.drop_constraint('refresh_tokens_token_key', 'refresh_tokens', type_='unique')
    op.create_index(op.f('ix_refresh_tokens_family_id'), 'refresh_tokens', ['family_id'], unique=False)
    op.create_index(op.f('ix_refresh_tokens_token_hash'), 'refresh_tokens', ['token_hash'], unique=True)
    op.drop_column('refresh_tokens', 'token')
    op.drop_column('refresh_tokens', 'is_revoked')
    op.add_column('users', sa.Column('tokens_valid_after', sa.DateTime(timezone=True), nullable=True))


def downgrade() -> None:
    op.drop_column('users', 'tokens_valid_after')
    op.add_column('refresh_tokens', sa.Column('is_revoked', sa.BOOLEAN(), autoincrement=False, nullable=False, server_default=sa.false()))
    op.add_column('refresh_tokens', sa.Column('token', sa.VARCHAR(length=500), autoincrement=False, nullable=True))
    op.drop_index(op.f('ix_refresh_tokens_token_hash'), table_name='refresh_tokens')
    op.drop_index(op.f('ix_refresh_tokens_family_id'), table_name='refresh_tokens')
    op.drop_column('refresh_tokens', 'revoked_reason')
    op.drop_column('refresh_tokens', 'revoked_at')
    op.drop_column('refresh_tokens', 'consumed_at')
    op.drop_column('refresh_tokens', 'family_id')
    op.drop_column('refresh_tokens', 'token_hash')
    op.drop_table('revoked_access_tokens')
