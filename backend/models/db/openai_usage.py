import uuid
from datetime import datetime
from decimal import Decimal

import sqlalchemy as sa
from sqlalchemy import DateTime, ForeignKey, Integer, Numeric, String
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from models.db.base import Base


class OpenAIUsageLog(Base):
    """Log d'un appel OpenAI, un row par appel avec tokens réels et coût en USD."""

    __tablename__ = "openai_usage_logs"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True,
        server_default=sa.text("gen_random_uuid()"), default=uuid.uuid4,
    )

    # SET NULL pour garder l'historique de coût même si le user est supprimé
    user_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="SET NULL"),
        index=True,
        nullable=True,
    )

    # Feature qui a déclenché l'appel : roadmap, coach, interview_start, interview_turn, interview_summary, cv_parser, etc.
    feature: Mapped[str] = mapped_column(String(50), index=True)
    model: Mapped[str] = mapped_column(String(50))

    prompt_tokens: Mapped[int] = mapped_column(Integer, server_default="0", default=0)
    completion_tokens: Mapped[int] = mapped_column(Integer, server_default="0", default=0)
    total_tokens: Mapped[int] = mapped_column(Integer, server_default="0", default=0)

    cost_usd: Mapped[Decimal] = mapped_column(Numeric(10, 4), server_default="0", default=Decimal("0"))

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=sa.text("now()"), nullable=False, index=True,
    )
