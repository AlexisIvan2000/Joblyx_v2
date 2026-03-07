from fastapi import APIRouter, BackgroundTasks, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from models.schemas import OnboardingRequest, OnboardingResponse, OnboardingStatus
from models.db_models import User
from services.onboarding.onboarding_service import OnboardingService
from services.roadmap.roadmap_service import RoadmapService
from core.database import AsyncSessionLocal
from api.dependencies import get_onboarding_service, get_current_user

router = APIRouter(prefix="/onboarding", tags=["onboarding"])


async def _generate_roadmap_background(user_id: str):
    # Ouvre une session indépendante pour le background task
    async with AsyncSessionLocal() as session:
        try:
            svc = RoadmapService(session)
            await svc.generate(user_id)
        except Exception:
            import logging
            logging.getLogger(__name__).exception("Background roadmap generation failed for user %s", user_id)


@router.post("", response_model=OnboardingResponse)
async def complete_onboarding(
    body: OnboardingRequest,
    background_tasks: BackgroundTasks,
    current_user: User = Depends(get_current_user),
    svc: OnboardingService = Depends(get_onboarding_service),
):
    result = await svc.complete_onboarding(str(current_user.id), body)
    # Lance la génération du roadmap en arrière-plan
    background_tasks.add_task(_generate_roadmap_background, str(current_user.id))
    return result


@router.get("/status", response_model=OnboardingStatus)
async def onboarding_status(
    current_user: User = Depends(get_current_user),
    svc: OnboardingService = Depends(get_onboarding_service),
):
    return await svc.check_status(str(current_user.id))


@router.get("", response_model=OnboardingResponse)
async def get_profile(
    current_user: User = Depends(get_current_user),
    svc: OnboardingService = Depends(get_onboarding_service),
):
    return await svc.get_profile(str(current_user.id))


@router.put("", response_model=OnboardingResponse)
async def update_profile(
    body: OnboardingRequest,
    background_tasks: BackgroundTasks,
    current_user: User = Depends(get_current_user),
    svc: OnboardingService = Depends(get_onboarding_service),
):
    result = await svc.update_profile(str(current_user.id), body)
    # Relance la génération du roadmap après modification du profil
    background_tasks.add_task(_generate_roadmap_background, str(current_user.id))
    return result
