import uuid
from datetime import datetime

import sqlalchemy as sa
from sqlalchemy import CheckConstraint, DateTime, ForeignKey, Integer, String, Text, UniqueConstraint
from sqlalchemy.dialects.postgresql import ARRAY, UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from models.db.base import Base
from models.db.user import User


class Career(Base):
    __tablename__ = "career"
    __table_args__ = (
        UniqueConstraint("user_id"),
        CheckConstraint("level = ANY (ARRAY['junior','mid','senior','reconversion'])", name="career_level_check"),
        CheckConstraint("language = ANY (ARRAY['fr','en','bilingual'])", name="career_language_check"),
        CheckConstraint("array_length(target_jobs, 1) <= 3", name="career_target_jobs_check"),
        CheckConstraint("generation_status = ANY (ARRAY['idle','generating','ready','error'])", name="career_generation_status_check"),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), index=True)
    level: Mapped[str] = mapped_column(Text)
    years_experience: Mapped[int | None] = mapped_column(Integer, nullable=True)
    target_jobs: Mapped[list[str] | None] = mapped_column(ARRAY(Text), nullable=True)
    city: Mapped[str] = mapped_column(Text)
    province: Mapped[str] = mapped_column(Text)
    language: Mapped[str | None] = mapped_column(Text, server_default="fr", nullable=True)
    previous_field: Mapped[str | None] = mapped_column(String(100), nullable=True)
    generation_status: Mapped[str] = mapped_column(String(20), server_default="idle")
    regeneration_count: Mapped[int] = mapped_column(Integer, server_default="0")
    regeneration_reset_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), server_default=sa.text("now()"), nullable=True)
    created_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), server_default=sa.text("now()"), nullable=True)
    updated_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), server_default=sa.text("now()"), onupdate=lambda: datetime.now(__import__("datetime").timezone.utc), nullable=True)

    user: Mapped[User] = relationship()


class UserSkill(Base):
    __tablename__ = "user_skills"
    __table_args__ = (
        UniqueConstraint("user_id", "skill_name"),
        CheckConstraint("proficiency::text = ANY (ARRAY['beginner','intermediate','advanced']::text[])", name="user_skills_proficiency_check"),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), index=True)
    skill_name: Mapped[str] = mapped_column(String(100))
    category: Mapped[str] = mapped_column(String(100))
    proficiency: Mapped[str] = mapped_column(String(20))
    created_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), server_default=sa.text("now()"), nullable=True)

    user: Mapped[User] = relationship()
