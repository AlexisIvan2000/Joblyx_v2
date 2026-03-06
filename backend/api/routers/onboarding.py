from fastapi import APIRouter, Depends
from models.schemas import OnboardingRequest, OnboardingResponse, OnboardingStatus
from models.db_models import User
from services.onboarding.onboarding_service import OnboardingService
from api.dependencies import get_onboarding_service, get_current_user

router = APIRouter(prefix="/onboarding", tags=["onboarding"])


@router.post("", response_model=OnboardingResponse)
async def complete_onboarding(
    body: OnboardingRequest,
    current_user: User = Depends(get_current_user),
    svc: OnboardingService = Depends(get_onboarding_service),
):
    return await svc.complete_onboarding(str(current_user.id), body)


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
    current_user: User = Depends(get_current_user),
    svc: OnboardingService = Depends(get_onboarding_service),
):
    return await svc.update_profile(str(current_user.id), body)
