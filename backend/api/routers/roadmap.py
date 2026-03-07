from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, status
from models.schemas import (
    RoadmapGenerateResponse,
    RoadmapStatusResponse,
    RoadmapResponse,
    RoadmapHistoryItem,
)
from models.db_models import User
from api.dependencies import get_current_user, get_roadmap_service
from services.roadmap.roadmap_service import RoadmapService

router = APIRouter(prefix="/roadmap", tags=["roadmap"])


async def _run_generate(user_id: str, svc: RoadmapService):
    # Wrapper pour le background task
    await svc.generate(user_id)


@router.post("/generate", response_model=RoadmapGenerateResponse)
async def generate_roadmap(
    background_tasks: BackgroundTasks,
    current_user: User = Depends(get_current_user),
    svc: RoadmapService = Depends(get_roadmap_service),
):
    background_tasks.add_task(_run_generate, str(current_user.id), svc)
    return {"status": "generating"}


@router.get("/status", response_model=RoadmapStatusResponse)
async def roadmap_status(
    current_user: User = Depends(get_current_user),
    svc: RoadmapService = Depends(get_roadmap_service),
):
    # Lit le generation_status depuis career + vérifie si un roadmap actif existe
    career = await svc._get_career(str(current_user.id))
    if not career:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Profile not found")

    roadmap = await svc.repo.get_active_by_user_id(str(current_user.id))
    return {
        "generation_status": career.generation_status,
        "has_roadmap": roadmap is not None,
    }


@router.get("", response_model=RoadmapResponse)
async def get_roadmap(
    current_user: User = Depends(get_current_user),
    svc: RoadmapService = Depends(get_roadmap_service),
):
    roadmap = await svc.repo.get_active_by_user_id(str(current_user.id))
    if not roadmap:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="No active roadmap")

    return {
        "id": str(roadmap.id),
        "target_jobs": roadmap.target_jobs,
        "phases": roadmap.phases,
        "status": roadmap.status,
        "created_at": roadmap.created_at.isoformat() if roadmap.created_at else None,
    }


@router.get("/history", response_model=list[RoadmapHistoryItem])
async def roadmap_history(
    current_user: User = Depends(get_current_user),
    svc: RoadmapService = Depends(get_roadmap_service),
):
    roadmaps = await svc.repo.get_history_by_user_id(str(current_user.id))
    return [
        {
            "id": str(r.id),
            "target_jobs": r.target_jobs,
            "status": r.status,
            "created_at": r.created_at.isoformat() if r.created_at else None,
        }
        for r in roadmaps
    ]
