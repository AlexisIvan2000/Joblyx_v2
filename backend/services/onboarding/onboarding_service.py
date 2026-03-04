from fastapi import HTTPException, status
from models.schemas import OnboardingRequest
from repositories.career_repository import CareerRepository


class OnboardingService:
    def __init__(self, career_repo: CareerRepository):
        self.repo = career_repo

    async def complete_onboarding(self, user_id: str, data: OnboardingRequest) -> dict:
        raise NotImplementedError
