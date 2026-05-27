from fastapi import APIRouter, Depends

from models.schemas import PhaseCreate, PhaseUpdate, PhaseResponse, PhaseReorder
from models.db_models import User
from api.v1.client.dependencies import get_current_user, get_roadmap_service
from services.roadmap.roadmap_service import RoadmapService
from api.v1.client.roadmap.presenters import phase_to_dict

router = APIRouter(tags=["roadmap"])


@router.post("/phases", response_model=PhaseResponse)
async def add_phase(
    body: PhaseCreate,
    current_user: User = Depends(get_current_user),
    svc: RoadmapService = Depends(get_roadmap_service),
):
    phase = await svc.add_phase(str(current_user.id), body)
    return phase_to_dict(phase)


# Doit être déclarée avant /phases/{phase_id} sinon "reorder" est capturé comme phase_id
@router.put("/phases/reorder")
async def reorder_phases(
    body: PhaseReorder,
    current_user: User = Depends(get_current_user),
    svc: RoadmapService = Depends(get_roadmap_service),
):
    await svc.reorder_phases(str(current_user.id), body.phase_ids)
    return {"ok": True}


@router.put("/phases/{phase_id}", response_model=PhaseResponse)
async def update_phase(
    phase_id: str,
    body: PhaseUpdate,
    current_user: User = Depends(get_current_user),
    svc: RoadmapService = Depends(get_roadmap_service),
):
    phase = await svc.update_phase(phase_id, str(current_user.id), body.model_dump(exclude_none=True))
    return phase_to_dict(phase)


@router.delete("/phases/{phase_id}", status_code=204)
async def delete_phase(
    phase_id: str,
    current_user: User = Depends(get_current_user),
    svc: RoadmapService = Depends(get_roadmap_service),
):
    await svc.delete_phase(phase_id, str(current_user.id))


@router.patch("/phases/{phase_id}/complete", response_model=PhaseResponse)
async def toggle_phase_complete(
    phase_id: str,
    current_user: User = Depends(get_current_user),
    svc: RoadmapService = Depends(get_roadmap_service),
):
    phase = await svc.toggle_phase_complete(phase_id, str(current_user.id))
    return phase_to_dict(phase)


@router.patch("/phases/{phase_id}/actions/{action_index}/complete", response_model=PhaseResponse)
async def toggle_action_complete(
    phase_id: str,
    action_index: int,
    current_user: User = Depends(get_current_user),
    svc: RoadmapService = Depends(get_roadmap_service),
):
    phase = await svc.toggle_action_complete(phase_id, str(current_user.id), action_index)
    return phase_to_dict(phase)


@router.patch("/phases/{phase_id}/skills/{skill_index}/complete", response_model=PhaseResponse)
async def toggle_skill_complete(
    phase_id: str,
    skill_index: int,
    current_user: User = Depends(get_current_user),
    svc: RoadmapService = Depends(get_roadmap_service),
):
    phase = await svc.toggle_skill_complete(phase_id, str(current_user.id), skill_index)
    return phase_to_dict(phase)
