"""add admin_notes field to users

Revision ID: e4f7b2c1d8a6
Revises: c7e9f2a3b1d4
Create Date: 2026-05-22 10:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = 'e4f7b2c1d8a6'
down_revision: Union[str, Sequence[str], None] = 'd8a3f1e2b5c9'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Ajoute admin_notes (champ libre rempli par l'admin sur la fiche user)."""
    op.add_column(
        "users",
        sa.Column("admin_notes", sa.Text(), nullable=True),
    )


def downgrade() -> None:
    """Rollback : retire admin_notes."""
    op.drop_column("users", "admin_notes")
