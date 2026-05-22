import uuid
from datetime import datetime

import sqlalchemy as sa
from sqlalchemy import DateTime, Integer, String, UniqueConstraint
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column

from models.db.base import Base


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
