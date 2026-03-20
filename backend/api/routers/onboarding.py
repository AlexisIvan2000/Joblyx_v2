from fastapi import APIRouter, BackgroundTasks, Depends, File, HTTPException, Request, UploadFile
from sqlalchemy.ext.asyncio import AsyncSession
from models.schemas import OnboardingRequest, OnboardingResponse, OnboardingStatus
from models.db_models import User
from services.onboarding.onboarding_service import OnboardingService
from services.roadmap.roadmap_service import RoadmapService
from services.ai.cv_parser import extract_skills_from_cv
from core.database import AsyncSessionLocal
from core.rate_limit import limiter, get_user_id_from_jwt
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

# Extrait les compétences d'un CV uploadé (PDF uniquement)
@router.post("/extract-skills")
@limiter.limit("5/minute", key_func=get_user_id_from_jwt)
async def extract_skills(
    request: Request,
    file: UploadFile = File(...),
    current_user: User = Depends(get_current_user),
):
    if not file.content_type or "pdf" not in file.content_type:
        raise HTTPException(status_code=400, detail="Only PDF files are accepted")

    content = await file.read()
    if len(content) > 5 * 1024 * 1024:  # 5 MB max
        raise HTTPException(status_code=400, detail="File too large (max 5 MB)")

    skills = await extract_skills_from_cv(content)
    return {"skills": skills}


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
