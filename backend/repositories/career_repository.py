from datetime import datetime

from sqlalchemy import delete, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from models.db_models import Career, MarketSkillsCache, UserSkill


class CareerRepository:
    def __init__(self, session: AsyncSession):
        self.session = session

    # Career

    async def get_by_user_id(self, user_id: str) -> Career | None:
        result = await self.session.execute(
            select(Career).where(Career.user_id == user_id)
        )
        return result.scalar_one_or_none()

    async def create(self, user_id: str, data: dict) -> Career:
        career = Career(user_id=user_id, **data)
        self.session.add(career)
        await self.session.flush()
        return career

    async def update_fields(self, user_id: str, data: dict) -> None:
        await self.session.execute(
            update(Career).where(Career.user_id == user_id).values(**data)
        )
        await self.session.flush()

    async def upsert(self, user_id: str, data: dict) -> bool:
        # Crée ou met à jour le profil career. Retourne True si création (premier passage).
        career = await self.get_by_user_id(user_id)
        if career:
            await self.update_fields(user_id, data)
            return False
        await self.create(user_id, data)
        return True

    async def set_generation_status(self, user_id: str, status: str) -> None:
        await self.update_fields(user_id, {"generation_status": status})

    async def increment_regeneration_count(self, user_id: str) -> None:
        await self.session.execute(
            update(Career).where(Career.user_id == user_id).values(
                regeneration_count=Career.regeneration_count + 1,
            )
        )
        await self.session.flush()

    async def reset_regeneration_counter(self, user_id: str, reset_at: datetime) -> None:
        await self.session.execute(
            update(Career).where(Career.user_id == user_id).values(
                regeneration_count=0,
                regeneration_reset_at=reset_at,
            )
        )
        await self.session.flush()

    # User skills

    async def get_skills(self, user_id: str) -> list[UserSkill]:
        result = await self.session.execute(
            select(UserSkill).where(UserSkill.user_id == user_id)
        )
        return list(result.scalars().all())

    async def delete_skills(self, user_id: str) -> None:
        await self.session.execute(
            delete(UserSkill).where(UserSkill.user_id == user_id)
        )
        await self.session.flush()

    async def replace_skills(self, user_id: str, skills_data: list[dict]) -> None:
        # Supprime toutes les compétences existantes et les remplace par les nouvelles
        await self.delete_skills(user_id)
        if skills_data:
            self.session.add_all([UserSkill(user_id=user_id, **s) for s in skills_data])
            await self.session.flush()

    # Market skills cache — lecture seule (le cron gère l'écriture)

    async def get_market_skills(
        self, target_jobs: list[str], city: str, province: str, cutoff: datetime,
    ) -> list[MarketSkillsCache]:
        result = await self.session.execute(
            select(MarketSkillsCache).where(
                MarketSkillsCache.job_title.in_(target_jobs),
                MarketSkillsCache.city == city,
                MarketSkillsCache.province == province,
                MarketSkillsCache.fetched_at >= cutoff,
            )
        )
        return list(result.scalars().all())
