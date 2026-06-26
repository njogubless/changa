"""add chama_invites table

Revision ID: 002_chama_invites
Revises: 001_initial
Create Date: 2026-03-27
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import UUID

revision = "002_chama_invites"
down_revision = "001_initial"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # ── Enums ──────────────────────────────────────────────────────────────────
    op.execute("CREATE TYPE invitestatus AS ENUM ('pending','accepted','declined','expired')")
    op.execute("CREATE TYPE invitemethod AS ENUM ('phone','code')")

    # ── chama_invites ──────────────────────────────────────────────────────────
    op.create_table(
        "chama_invites",
        sa.Column("id",           UUID(as_uuid=True), primary_key=True, nullable=False),
        sa.Column("chama_id",     UUID(as_uuid=True),
                  sa.ForeignKey("chamas.id", ondelete="CASCADE"), nullable=False),
        sa.Column("invited_by",   UUID(as_uuid=True),
                  sa.ForeignKey("users.id"), nullable=False),

        # Phone invite
        sa.Column("phone",        sa.String(20), nullable=True),
        sa.Column("user_id",      UUID(as_uuid=True),
                  sa.ForeignKey("users.id"), nullable=True),

        # Code invite
        sa.Column("invite_code",  sa.String(12), nullable=True),

        sa.Column("method",       sa.Enum("phone", "code", name="invitemethod"),
                  nullable=False, server_default="phone"),
        sa.Column("status",       sa.Enum("pending", "accepted", "declined", "expired",
                  name="invitestatus"), nullable=False, server_default="pending"),

        sa.Column("created_at",   sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column("expires_at",   sa.DateTime(timezone=True), nullable=False),
        sa.Column("responded_at", sa.DateTime(timezone=True), nullable=True),
    )

    # ── Indexes ────────────────────────────────────────────────────────────────
    op.create_index("ix_chama_invites_chama_id",    "chama_invites", ["chama_id"])
    op.create_index("ix_chama_invites_user_id",     "chama_invites", ["user_id"])
    op.create_index("ix_chama_invites_phone",       "chama_invites", ["phone"])
    op.create_index("ix_chama_invites_invite_code", "chama_invites", ["invite_code"], unique=True)
    op.create_index("ix_chama_invites_status",      "chama_invites", ["status"])


def downgrade() -> None:
    op.drop_table("chama_invites")
    op.execute("DROP TYPE IF EXISTS invitestatus")
    op.execute("DROP TYPE IF EXISTS invitemethod")
