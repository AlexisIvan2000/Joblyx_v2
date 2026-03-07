import uuid
from datetime import datetime, timezone

import sqlalchemy as sa
from sqlalchemy import String, Boolean, DateTime, ForeignKey, Text, Integer, UniqueConstraint, CheckConstraint
from sqlalchemy.dialects.postgresql import UUID, ARRAY, JSONB
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, relationship


class Base(DeclarativeBase):
    pass


class User(Base):
    __tablename__ = "users"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    first_name: Mapped[str] = mapped_column(String(100))
    last_name: Mapped[str] = mapped_column(String(100))
    email: Mapped[str] = mapped_column(String(255), unique=True, index=True)
    password_hash: Mapped[str] = mapped_column(Text)
    is_verified: Mapped[bool] = mapped_column(Boolean, default=False)
    verification_code_hash: Mapped[str | None] = mapped_column(String(255), nullable=True)
    verification_code_expires_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    pending_email: Mapped[str | None] = mapped_column(String(255), nullable=True)
    reset_code_hash: Mapped[str | None] = mapped_column(String(255), nullable=True)
    reset_code_expires_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    email_change_code_hash: Mapped[str | None] = mapped_column(String(255), nullable=True)
    email_change_code_expires_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    verification_attempts: Mapped[int] = mapped_column(Integer, default=0)
    last_code_sent_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    code_resend_count: Mapped[int] = mapped_column(Integer, default=0)
    avatar_url: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc))

    refresh_tokens: Mapped[list["RefreshToken"]] = relationship(back_populates="user", cascade="all, delete-orphan")


class RefreshToken(Base):
    __tablename__ = "refresh_tokens"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), index=True)
    token_hash: Mapped[str] = mapped_column(String(64), unique=True, index=True)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    revoked: Mapped[bool] = mapped_column(Boolean, default=False)
    revoked_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    device_info: Mapped[str | None] = mapped_column(String(255), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))

    user: Mapped["User"] = relationship(back_populates="refresh_tokens")


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
    onboarding_completed: Mapped[bool | None] = mapped_column(Boolean, server_default="false", nullable=True)
    generation_status: Mapped[str] = mapped_column(String(20), server_default="idle")
    created_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), server_default=sa.text("now()"), nullable=True)
    updated_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), server_default=sa.text("now()"), nullable=True)

    user: Mapped["User"] = relationship()


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

    user: Mapped["User"] = relationship()


class Roadmap(Base):
    __tablename__ = "roadmaps"
    __table_args__ = (
        CheckConstraint("status::text = ANY (ARRAY['active','completed','archived']::text[])", name="roadmaps_status_check"),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), index=True)
    target_jobs: Mapped[list[str]] = mapped_column(ARRAY(Text))
    market_data: Mapped[dict | None] = mapped_column(JSONB, nullable=True)
    phases: Mapped[dict] = mapped_column(JSONB)
    status: Mapped[str | None] = mapped_column(String(20), server_default="active", nullable=True)
    created_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), server_default=sa.text("now()"), nullable=True)

    user: Mapped["User"] = relationship()


class MarketSkillsCache(Base):
    __tablename__ = "market_skills_cache"
    __table_args__ = (
        UniqueConstraint("job_title", "city", "province"),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    job_title: Mapped[str] = mapped_column(String(200))
    city: Mapped[str] = mapped_column(String(100))
    province: Mapped[str] = mapped_column(String(5))
    top_skills: Mapped[dict] = mapped_column(JSONB)
    job_count: Mapped[int | None] = mapped_column(Integer, nullable=True)
    fetched_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), server_default=sa.text("now()"), nullable=True)
