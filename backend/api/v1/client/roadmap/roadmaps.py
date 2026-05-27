from fastapi import APIRouter, Depends

from models.schemas import (
    RoadmapResponse,
    RoadmapStatusResponse,
    RoadmapHistoryItem,
    RoadmapCreate,
    RegenerationStatusResponse,
)
from models.db_models import User
from api.v1.client.dependencies import get_current_user, get_roadmap_service
from services.roadmap.roadmap_service import RoadmapService
from api.v1.client.roadmap.presenters import roadmap_to_response

router = APIRouter(tags=["roadmap"])


# Routes à chemin littéral, déclarées avant /{roadmap_id}

@router.post("/manual", response_model=RoadmapResponse)
async def create_manual_roadmap(
    body: RoadmapCreate,
    current_user: User = Depends(get_current_user),
    svc: RoadmapService = Depends(get_roadmap_service),
):
    roadmap = await svc.create_manual_roadmap(str(current_user.id), body.phases)
    return roadmap_to_response(roadmap)


@router.get("/regeneration-status", response_model=RegenerationStatusResponse)
async def regeneration_status(
    current_user: User = Depends(get_current_user),
    svc: RoadmapService = Depends(get_roadmap_service),
):
    return await svc.get_regeneration_status(str(current_user.id))


@router.get("/status", response_model=RoadmapStatusResponse)
async def roadmap_status(
    current_user: User = Depends(get_current_user),
    svc: RoadmapService = Depends(get_roadmap_service),
):
    return await svc.get_roadmap_status(str(current_user.id))


@router.post("/archive")
async def archive_roadmap(
    current_user: User = Depends(get_current_user),
    svc: RoadmapService = Depends(get_roadmap_service),
):
    await svc.archive_active_roadmap(str(current_user.id))
    return {"message": "Roadmap archived"}


@router.get("/history", response_model=list[RoadmapHistoryItem])
async def roadmap_history(
    current_user: User = Depends(get_current_user),
    svc: RoadmapService = Depends(get_roadmap_service),
):
    roadmaps = await svc.get_history(str(current_user.id))
    return [roadmap_to_response(r) for r in roadmaps]


# Routes à paramètre dynamique, déclarées en dernier

@router.get("/{roadmap_id}", response_model=RoadmapResponse)
async def get_roadmap_by_id(
    roadmap_id: str,
    current_user: User = Depends(get_current_user),
    svc: RoadmapService = Depends(get_roadmap_service),
):
    roadmap = await svc.get_by_id(roadmap_id, str(current_user.id))
    return roadmap_to_response(roadmap)


@router.post("/{roadmap_id}/restore", response_model=RoadmapResponse)
async def restore_roadmap(
    roadmap_id: str,
    current_user: User = Depends(get_current_user),
    svc: RoadmapService = Depends(get_roadmap_service),
):
    roadmap = await svc.restore_roadmap(roadmap_id, str(current_user.id))
    return roadmap_to_response(roadmap)


@router.delete("/{roadmap_id}")
async def delete_roadmap(
    roadmap_id: str,
    current_user: User = Depends(get_current_user),
    svc: RoadmapService = Depends(get_roadmap_service),
):
    await svc.delete_roadmap(roadmap_id, str(current_user.id))
    return {"message": "Roadmap deleted"}
