from fastapi import APIRouter, Depends

from models.schemas import RoadmapResponse
from models.db_models import User
from api.v1.client.dependencies import get_current_user, get_roadmap_service
from services.roadmap.roadmap_service import RoadmapService
from api.v1.client.roadmap.presenters import roadmap_to_response
from api.v1.client.roadmap.generation import router as generation_router
from api.v1.client.roadmap.career import router as career_router
from api.v1.client.roadmap.phases import router as phases_router
from api.v1.client.roadmap.roadmaps import router as roadmaps_router

router = APIRouter(prefix="/roadmap", tags=["roadmap"])


# Routes racine /roadmap (path vide, impossible sur un sous router sans préfixe)

@router.get("", response_model=RoadmapResponse)
async def get_roadmap(
    current_user: User = Depends(get_current_user),
    svc: RoadmapService = Depends(get_roadmap_service),
):
    roadmap = await svc.get_active(str(current_user.id))
    return roadmap_to_response(roadmap)


@router.delete("")
async def delete_all_roadmaps(
    current_user: User = Depends(get_current_user),
    svc: RoadmapService = Depends(get_roadmap_service),
):
    count = await svc.delete_all_archived(str(current_user.id))
    return {"message": f"{count} roadmap(s) deleted", "count": count}


# roadmaps_router inclus en dernier car il contient /{roadmap_id} (catch-all)
router.include_router(generation_router)
router.include_router(career_router)
router.include_router(phases_router)
router.include_router(roadmaps_router)
