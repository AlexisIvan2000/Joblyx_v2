from fastapi import APIRouter, Depends

from models.schemas import CareerProfileResponse, CareerProfileUpdate
from models.db_models import User
from api.v1.client.dependencies import get_current_user, get_roadmap_service
from services.roadmap.roadmap_service import RoadmapService

router = APIRouter(tags=["roadmap"])


@router.get("/career", response_model=CareerProfileResponse)
async def get_career_profile(
    current_user: User = Depends(get_current_user),
    svc: RoadmapService = Depends(get_roadmap_service),
):
    return await svc.get_career_profile(str(current_user.id))


@router.put("/career", response_model=CareerProfileResponse)
async def update_career_profile(
    body: CareerProfileUpdate,
    current_user: User = Depends(get_current_user),
    svc: RoadmapService = Depends(get_roadmap_service),
):
    return await svc.update_career_profile(str(current_user.id), body)
