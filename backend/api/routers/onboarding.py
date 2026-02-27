from fastapi import APIRouter, BackgroundTasks, Depends
from models.schemas import OnboardingRequest, OnboardingResponse
from services.onboarding.onboarding_service import OnboardingService
from api.dependencies import get_onboarding_service, get_current_user

router = APIRouter(prefix="/onboarding", tags=["onboarding"])


def _generate_roadmap_stub(user_id: str) -> None:
    # TODO: pipeline JSearch + spaCy + GPT to populate roadmap
    pass


@router.post("", status_code=202, response_model=OnboardingResponse)
def onboarding(
    body: OnboardingRequest,
    background_tasks: BackgroundTasks,
    current_user: dict = Depends(get_current_user),
    svc: OnboardingService = Depends(get_onboarding_service),
):
    result = svc.complete_onboarding(str(current_user["id"]), body)
    background_tasks.add_task(_generate_roadmap_stub, str(current_user["id"]))
    return result
