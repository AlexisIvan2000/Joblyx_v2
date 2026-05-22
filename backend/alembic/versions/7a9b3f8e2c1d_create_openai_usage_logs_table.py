"""create openai_usage_logs table

Revision ID: 7a9b3f8e2c1d
Revises: e4f7b2c1d8a6
Create Date: 2026-05-22 14:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import UUID


revision: str = '7a9b3f8e2c1d'
down_revision: Union[str, Sequence[str], None] = 'e4f7b2c1d8a6'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Table de tracking des appels OpenAI, un log par appel avec tokens et coût réel."""
    op.create_table(
        "openai_usage_logs",
        sa.Column("id", UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        # user_id en SET NULL, on garde l'historique de coût même si le user est supprimé
        sa.Column("user_id", UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="SET NULL"), nullable=True),
        sa.Column("feature", sa.String(50), nullable=False),
        sa.Column("model", sa.String(50), nullable=False),
        sa.Column("prompt_tokens", sa.Integer, nullable=False, server_default="0"),
        sa.Column("completion_tokens", sa.Integer, nullable=False, server_default="0"),
        sa.Column("total_tokens", sa.Integer, nullable=False, server_default="0"),
        # numeric pour précision financière, 4 décimales suffisent pour les sommes par mois
        sa.Column("cost_usd", sa.Numeric(10, 4), nullable=False, server_default="0"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
    )
    op.create_index("ix_openai_usage_user_id", "openai_usage_logs", ["user_id"])
    op.create_index("ix_openai_usage_created_at", "openai_usage_logs", ["created_at"])
    op.create_index("ix_openai_usage_feature", "openai_usage_logs", ["feature"])


def downgrade() -> None:
    """Rollback, supprime la table de tracking."""
    op.drop_index("ix_openai_usage_feature", table_name="openai_usage_logs")
    op.drop_index("ix_openai_usage_created_at", table_name="openai_usage_logs")
    op.drop_index("ix_openai_usage_user_id", table_name="openai_usage_logs")
    op.drop_table("openai_usage_logs")
