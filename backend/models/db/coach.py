import uuid
from datetime import datetime

import sqlalchemy as sa
from sqlalchemy import DateTime, ForeignKey, Integer, String, Text
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from models.db.base import Base
from models.db.user import User


class CoachSession(Base):
    __tablename__ = "coach_sessions"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), index=True)
    job_title: Mapped[str | None] = mapped_column(String(200), nullable=True)
    company_name: Mapped[str | None] = mapped_column(String(200), nullable=True)
    job_description: Mapped[str] = mapped_column(Text)
    cv_file_key: Mapped[str | None] = mapped_column(String(500), nullable=True)
    cv_text: Mapped[str | None] = mapped_column(Text, nullable=True)
    compatibility_score: Mapped[int | None] = mapped_column(Integer, nullable=True)
    analysis: Mapped[dict | None] = mapped_column(JSONB, nullable=True)
    cv_hash: Mapped[str | None] = mapped_column(String(64), nullable=True)
    job_description_hash: Mapped[str | None] = mapped_column(String(64), nullable=True)
    language: Mapped[str | None] = mapped_column(String(10), server_default="fr", nullable=True)
    created_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), server_default=sa.text("now()"), nullable=True)

    user: Mapped[User] = relationship()
