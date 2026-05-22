import uuid
from datetime import datetime, timezone

import sqlalchemy as sa
from sqlalchemy import Boolean, CheckConstraint, DateTime, ForeignKey, Integer, String, Text
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from models.db.base import Base
from models.db.user import User


class Roadmap(Base):
    __tablename__ = "roadmaps"
    __table_args__ = (
        CheckConstraint("status::text = ANY (ARRAY['active','completed','archived']::text[])", name="roadmaps_status_check"),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), index=True)
    summary: Mapped[dict | None] = mapped_column(JSONB, nullable=True)
    status: Mapped[str | None] = mapped_column(String(20), server_default="active", nullable=True)
    created_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), server_default=sa.text("now()"), nullable=True)

    user: Mapped[User] = relationship()
    phases: Mapped[list["RoadmapPhase"]] = relationship(back_populates="roadmap", cascade="all, delete-orphan", order_by="RoadmapPhase.position")


class RoadmapPhase(Base):
    __tablename__ = "roadmap_phases"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    roadmap_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("roadmaps.id", ondelete="CASCADE"), index=True)
    phase_number: Mapped[int] = mapped_column(Integer)
    title: Mapped[str] = mapped_column(String(200))
    duration_weeks: Mapped[int | None] = mapped_column(Integer, nullable=True)
    objective: Mapped[str | None] = mapped_column(Text, nullable=True)
    milestone: Mapped[str | None] = mapped_column(Text, nullable=True)
    completed: Mapped[bool] = mapped_column(Boolean, default=False)
    custom: Mapped[bool] = mapped_column(Boolean, default=False)
    user_notes: Mapped[str | None] = mapped_column(Text, nullable=True)
    position: Mapped[int] = mapped_column(Integer)
    skills: Mapped[list | None] = mapped_column(JSONB, server_default="[]", nullable=True)
    actions: Mapped[list | None] = mapped_column(JSONB, server_default="[]", nullable=True)
    resources: Mapped[list | None] = mapped_column(JSONB, server_default="[]", nullable=True)
    certifications: Mapped[list | None] = mapped_column(JSONB, server_default="[]", nullable=True)
    projects: Mapped[list | None] = mapped_column(JSONB, server_default="[]", nullable=True)
    created_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), server_default=sa.text("now()"), nullable=True)
    updated_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), server_default=sa.text("now()"), onupdate=lambda: datetime.now(timezone.utc), nullable=True)

    roadmap: Mapped[Roadmap] = relationship(back_populates="phases")
