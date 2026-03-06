from sqlalchemy import select, update, delete
from sqlalchemy.ext.asyncio import AsyncSession

from models.db_models import Career, UserSkill


class OnboardingRepository:
    def __init__(self, session: AsyncSession):
        self.session = session

    async def create_career(self, user_id: str, data: dict) -> Career:
        career = Career(user_id=user_id, onboarding_completed=True, **data)
        self.session.add(career)
        await self.session.flush()
        return career

    async def create_user_skills(self, user_id: str, skills: list[dict]) -> list[UserSkill]:
        skill_objects = [UserSkill(user_id=user_id, **s) for s in skills]
        self.session.add_all(skill_objects)
        await self.session.flush()
        return skill_objects

    async def get_career_by_user_id(self, user_id: str) -> Career | None:
        result = await self.session.execute(
            select(Career).where(Career.user_id == user_id)
        )
        return result.scalar_one_or_none()

    async def get_skills_by_user_id(self, user_id: str) -> list[UserSkill]:
        result = await self.session.execute(
            select(UserSkill).where(UserSkill.user_id == user_id)
        )
        return list(result.scalars().all())

    async def update_career(self, user_id: str, data: dict) -> Career:
        await self.session.execute(
            update(Career).where(Career.user_id == user_id).values(**data)
        )
        await self.session.flush()
        result = await self.session.execute(
            select(Career).where(Career.user_id == user_id)
        )
        return result.scalar_one()

    async def delete_skills_by_user_id(self, user_id: str) -> None:
        await self.session.execute(
            delete(UserSkill).where(UserSkill.user_id == user_id)
        )
        await self.session.flush()

    async def has_profile(self, user_id: str) -> bool:
        result = await self.session.execute(
            select(Career.onboarding_completed).where(Career.user_id == user_id)
        )
        value = result.scalar_one_or_none()
        return bool(value)
