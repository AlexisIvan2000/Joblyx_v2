"""add role and is_active fields to users

Revision ID: c7e9f2a3b1d4
Revises: a8cd179de68e
Create Date: 2026-05-21 14:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'c7e9f2a3b1d4'
down_revision: Union[str, Sequence[str], None] = 'a8cd179de68e'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Ajoute role + is_active + traçabilité de désactivation sur users."""
    op.add_column(
        "users",
        sa.Column("role", sa.String(20), server_default="user", nullable=False),
    )
    op.add_column(
        "users",
        sa.Column("is_active", sa.Boolean(), server_default=sa.text("true"), nullable=False),
    )
    op.add_column(
        "users",
        sa.Column("deactivated_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.add_column(
        "users",
        sa.Column("deactivation_reason", sa.Text(), nullable=True),
    )
    op.create_check_constraint(
        "users_role_check",
        "users",
        "role IN ('user', 'admin', 'super_admin')",
    )
    op.create_index("ix_users_role", "users", ["role"])
    op.create_index("ix_users_is_active", "users", ["is_active"])


def downgrade() -> None:
    """Rollback : retire role + is_active."""
    op.drop_index("ix_users_is_active", table_name="users")
    op.drop_index("ix_users_role", table_name="users")
    op.drop_constraint("users_role_check", "users", type_="check")
    op.drop_column("users", "deactivation_reason")
    op.drop_column("users", "deactivated_at")
    op.drop_column("users", "is_active")
    op.drop_column("users", "role")
