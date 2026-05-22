from core.exceptions import OnboardingAlreadyCompleted, ProfileNotFound
from models.schemas import OnboardingRequest
from repositories.onboarding_repository import OnboardingRepository


class OnboardingService:
    def __init__(self, repo: OnboardingRepository):
        self.repo = repo

    async def complete_onboarding(self, user_id: str, data: OnboardingRequest) -> dict:
        if await self.repo.has_profile(user_id):
            raise OnboardingAlreadyCompleted()

        career_data = {
            "level": data.level.value,
            "years_experience": data.years_experience,
            "target_jobs": data.target_jobs,
            "city": data.city,
            "province": data.province,
            "language": data.language.value,
            "previous_field": data.previous_field,
        }
        await self.repo.create_career(user_id, career_data)

        skills_data = [
            {
                "skill_name": s.skill_name,
                "category": s.category,
                "proficiency": s.proficiency.value,
            }
            for s in data.skills
        ]
        await self.repo.create_user_skills(user_id, skills_data)

        return await self._build_profile(user_id)

    async def get_profile(self, user_id: str) -> dict:
        career = await self.repo.get_career_by_user_id(user_id)
        if not career:
            raise ProfileNotFound()
        return await self._build_profile(user_id)

    async def update_profile(self, user_id: str, data: OnboardingRequest) -> dict:
        career = await self.repo.get_career_by_user_id(user_id)
        if not career:
            raise ProfileNotFound()

        career_data = {
            "level": data.level.value,
            "years_experience": data.years_experience,
            "target_jobs": data.target_jobs,
            "city": data.city,
            "province": data.province,
            "language": data.language.value,
            "previous_field": data.previous_field,
        }
        await self.repo.update_career(user_id, career_data)

        await self.repo.delete_skills_by_user_id(user_id)
        skills_data = [
            {
                "skill_name": s.skill_name,
                "category": s.category,
                "proficiency": s.proficiency.value,
            }
            for s in data.skills
        ]
        await self.repo.create_user_skills(user_id, skills_data)

        return await self._build_profile(user_id)

    async def check_status(self, user_id: str) -> dict:
        has_profile = await self.repo.has_profile(user_id)
        return {"has_profile": has_profile}

    async def _build_profile(self, user_id: str) -> dict:
        career = await self.repo.get_career_by_user_id(user_id)
        skills = await self.repo.get_skills_by_user_id(user_id)

        return {
            "level": career.level,
            "years_experience": career.years_experience,
            "target_jobs": career.target_jobs,
            "city": career.city,
            "province": career.province,
            "language": career.language,
            "previous_field": career.previous_field,
            "skills": [
                {
                    "skill_name": s.skill_name,
                    "category": s.category,
                    "proficiency": s.proficiency,
                }
                for s in skills
            ],
            "onboarding_completed": bool(career.onboarding_completed),
        }
