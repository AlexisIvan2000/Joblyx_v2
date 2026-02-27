from fastapi import HTTPException, status
from models.schemas import OnboardingRequest
from repositories.career_repository import CareerRepository


class OnboardingService:
    def __init__(self, career_repo: CareerRepository):
        self.repo = career_repo

    def complete_onboarding(self, user_id: str, data: OnboardingRequest) -> dict:
        # Idempotence check
        existing = self.repo.get_career_profile_by_user_id(user_id)
        if existing:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Onboarding already completed",
            )

        # Create career profile
        profile = self.repo.create_career_profile({
            "user_id": user_id,
            "level": data.level.value,
            "years_experience": data.years_experience,
            "target_jobs": data.target_jobs,
            "city": data.city,
            "province": data.province,
            "language": data.language.value,
            "onboarding_completed": True,
        })

        # Bulk insert skills
        skills_data = [
            {
                "user_id": user_id,
                "skill_name": skill.skill_name,
                "category": skill.category,
                "level": skill.level.value,
            }
            for skill in data.skills
        ]
        self.repo.create_user_skills(skills_data)

        # Create roadmap stub
        roadmap = self.repo.create_roadmap({
            "user_id": user_id,
            "status": "processing",
            "duration_days": 60,
        })

        return {
            "message": "Onboarding completed successfully",
            "roadmap_id": str(roadmap["id"]),
        }
