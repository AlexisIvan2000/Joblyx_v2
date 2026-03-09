from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, Request, status
from core.rate_limit import limiter, get_user_id_from_jwt
from models.schemas import (
    RoadmapGenerateResponse,
    RoadmapStatusResponse,
    RoadmapResponse,
    RoadmapHistoryItem,
    RoadmapPhasesUpdate,
    RoadmapPhaseCreate,
    RegenerationStatusResponse,
)
from models.db_models import User
from api.dependencies import get_current_user, get_roadmap_service
from services.roadmap.roadmap_service import RoadmapService

router = APIRouter(prefix="/roadmap", tags=["roadmap"])


async def _run_generate(user_id: str, svc: RoadmapService):
    # Wrapper pour le background task
    await svc.generate(user_id)


def _roadmap_to_response(roadmap) -> dict:
    return {
        "id": str(roadmap.id),
        "target_jobs": roadmap.target_jobs,
        "phases": roadmap.phases,
        "status": roadmap.status,
        "created_at": roadmap.created_at.isoformat() if roadmap.created_at else None,
    }


@router.post("/generate", response_model=RoadmapGenerateResponse)
@limiter.limit("3/minute", key_func=get_user_id_from_jwt)
async def generate_roadmap(
    request: Request,
    background_tasks: BackgroundTasks,
    current_user: User = Depends(get_current_user),
    svc: RoadmapService = Depends(get_roadmap_service),
):
    user_id = str(current_user.id)

    # Vérification de la limite de régénération
    regen = await svc.check_regeneration_limit(user_id)
    if not regen["allowed"]:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail={
                "error": "Vous avez atteint la limite de 5 régénérations ce mois-ci",
                "remaining": 0,
                "resets_at": regen["resets_at"],
            },
        )

    background_tasks.add_task(_run_generate, user_id, svc)
    return {"status": "generating"}


@router.get("/regeneration-status", response_model=RegenerationStatusResponse)
async def regeneration_status(
    current_user: User = Depends(get_current_user),
    svc: RoadmapService = Depends(get_roadmap_service),
):
    regen = await svc.check_regeneration_limit(str(current_user.id))
    return {
        "used": regen["used"],
        "limit": 5,
        "remaining": regen["remaining"],
        "resets_at": regen["resets_at"],
    }


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

    return _roadmap_to_response(roadmap)


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


# ─── Endpoints de modification des phases (zéro appel GPT) ──────

@router.put("/{roadmap_id}/phases", response_model=RoadmapResponse)
async def update_phases(
    roadmap_id: str,
    body: RoadmapPhasesUpdate,
    current_user: User = Depends(get_current_user),
    svc: RoadmapService = Depends(get_roadmap_service),
):
    """Met à jour le JSONB phases complet (réordonnement, édition, notes, etc.)."""
    phases_dicts = [p.model_dump() for p in body.phases]
    roadmap = await svc.update_phases(roadmap_id, str(current_user.id), phases_dicts)
    if not roadmap:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Roadmap not found")
    await svc.session.commit()
    return _roadmap_to_response(roadmap)


@router.post("/{roadmap_id}/phases", response_model=RoadmapResponse)
async def add_phase(
    roadmap_id: str,
    body: RoadmapPhaseCreate,
    current_user: User = Depends(get_current_user),
    svc: RoadmapService = Depends(get_roadmap_service),
):
    """Ajoute une phase custom au roadmap."""
    phase_dict = body.model_dump(exclude={"position"})
    roadmap = await svc.add_phase(roadmap_id, str(current_user.id), phase_dict, body.position)
    if not roadmap:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Roadmap not found")
    await svc.session.commit()
    return _roadmap_to_response(roadmap)


@router.delete("/{roadmap_id}/phases/{phase_number}", response_model=RoadmapResponse)
async def delete_phase(
    roadmap_id: str,
    phase_number: int,
    current_user: User = Depends(get_current_user),
    svc: RoadmapService = Depends(get_roadmap_service),
):
    """Supprime une phase par son numéro."""
    roadmap = await svc.delete_phase(roadmap_id, str(current_user.id), phase_number)
    if not roadmap:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Roadmap or phase not found")
    await svc.session.commit()
    return _roadmap_to_response(roadmap)


@router.patch("/{roadmap_id}/phases/{phase_number}/complete", response_model=RoadmapResponse)
async def toggle_phase_complete(
    roadmap_id: str,
    phase_number: int,
    current_user: User = Depends(get_current_user),
    svc: RoadmapService = Depends(get_roadmap_service),
):
    """Toggle le statut completed d'une phase."""
    roadmap = await svc.toggle_phase_complete(roadmap_id, str(current_user.id), phase_number)
    if not roadmap:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Roadmap or phase not found")
    await svc.session.commit()
    return _roadmap_to_response(roadmap)


@router.patch("/{roadmap_id}/phases/{phase_number}/actions/{action_index}/complete", response_model=RoadmapResponse)
async def toggle_action_complete(
    roadmap_id: str,
    phase_number: int,
    action_index: int,
    current_user: User = Depends(get_current_user),
    svc: RoadmapService = Depends(get_roadmap_service),
):
    """Toggle le statut completed d'une action spécifique."""
    roadmap = await svc.toggle_action_complete(roadmap_id, str(current_user.id), phase_number, action_index)
    if not roadmap:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Roadmap, phase or action not found")
    await svc.session.commit()
    return _roadmap_to_response(roadmap)
