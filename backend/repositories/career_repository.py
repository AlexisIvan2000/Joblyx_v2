from sqlalchemy.ext.asyncio import AsyncSession


class CareerRepository:
    def __init__(self, session: AsyncSession):
        self.session = session

    async def get_career_profile_by_user_id(self, user_id: str):
        raise NotImplementedError

    async def create_career_profile(self, profile_data: dict):
        raise NotImplementedError

    async def create_user_skills(self, skills_data: list[dict]):
        raise NotImplementedError

    async def create_roadmap(self, roadmap_data: dict):
        raise NotImplementedError

    async def get_roadmap_by_user_id(self, user_id: str):
        raise NotImplementedError

    async def get_user_skills_by_user_id(self, user_id: str):
        raise NotImplementedError
