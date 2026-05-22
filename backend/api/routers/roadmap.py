import asyncio
import json

from fastapi import APIRouter, Depends, File, HTTPException, Request, UploadFile
from fastapi.responses import StreamingResponse
from core.rate_limit import limiter, get_user_id_from_jwt
from models.schemas import (
    RoadmapGenerateRequest,
    RoadmapStatusResponse,
    RoadmapResponse,
    RoadmapHistoryItem,
    RoadmapCreate,
    PhaseCreate,
    PhaseUpdate,
    PhaseResponse,
    PhaseReorder,
    RegenerationStatusResponse,
    CareerProfileResponse,
    CareerProfileUpdate,
)
from models.db_models import User
from api.dependencies import get_current_user, get_roadmap_service
from services.roadmap.roadmap_service import RoadmapService
from services.ai.cv_parser import extract_skills_from_cv_stream

router = APIRouter(prefix="/roadmap", tags=["roadmap"])


def _phase_to_dict(phase) -> dict:
    return {
        "id": str(phase.id),
        "phase_number": phase.phase_number,
        "title": phase.title,
        "duration_weeks": phase.duration_weeks,
        "objective": phase.objective,
        "skills": phase.skills or [],
        "actions": phase.actions or [],
        "resources": phase.resources or [],
        "certifications": phase.certifications or [],
        "projects": phase.projects or [],
        "milestone": phase.milestone,
        "completed": phase.completed,
        "custom": phase.custom,
        "user_notes": phase.user_notes,
        "position": phase.position,
    }


def _roadmap_to_response(roadmap) -> dict:
    return {
        "id": str(roadmap.id),
        "summary": roadmap.summary,
        "phases": [_phase_to_dict(p) for p in sorted(roadmap.phases, key=lambda p: p.position)],
        "status": roadmap.status,
        "created_at": roadmap.created_at.isoformat() if roadmap.created_at else None,
    }


# Génération (SSE streaming)

@router.post("/generate")
@limiter.limit("3/minute", key_func=get_user_id_from_jwt)
async def generate_roadmap(
    request: Request,
    body: RoadmapGenerateRequest,
    current_user: User = Depends(get_current_user),
    svc: RoadmapService = Depends(get_roadmap_service),
):
    user_id = str(current_user.id)

    career_data = {
        "level": body.level.value,
        "years_experience": body.years_experience,
        "target_jobs": body.target_jobs,
        "city": body.city,
        "province": body.province,
        "language": body.language.value,
        "previous_field": body.previous_field,
    }
    skills_data = [
        {"skill_name": s.skill_name, "category": s.category, "proficiency": s.proficiency.value}
        for s in body.skills
    ]
    is_first = await svc.save_career_and_skills(user_id, career_data, skills_data)
    await svc.session.commit()

    if not is_first:
        await svc.ensure_regeneration_allowed(user_id)

    async def _stream():
        async for event in svc.generate_stream(user_id):
            yield event

    return StreamingResponse(_stream(), media_type="text/event-stream")


# Régénération (sans body — utilise les données career existantes)

@router.post("/regenerate")
@limiter.limit("3/minute", key_func=get_user_id_from_jwt)
async def regenerate_roadmap(
    request: Request,
    current_user: User = Depends(get_current_user),
    svc: RoadmapService = Depends(get_roadmap_service),
):
    user_id = str(current_user.id)
    await svc.ensure_career_exists(user_id)
    await svc.ensure_regeneration_allowed(user_id)

    async def _stream():
        async for event in svc.generate_stream(user_id):
            yield event

    return StreamingResponse(_stream(), media_type="text/event-stream")


# Career profile (get / update)

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


# Création manuelle

@router.post("/manual", response_model=RoadmapResponse)
async def create_manual_roadmap(
    body: RoadmapCreate,
    current_user: User = Depends(get_current_user),
    svc: RoadmapService = Depends(get_roadmap_service),
):
    roadmap = await svc.create_manual_roadmap(str(current_user.id), body.phases)
    return _roadmap_to_response(roadmap)


# Extraction de skills depuis CV (SSE streaming)

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
    if len(content) > 5 * 1024 * 1024:
        raise HTTPException(status_code=400, detail="File too large (max 5 MB)")

    async def _stream():
        yield 'event: status\ndata: {"status":"extracting"}\n\n'
        async for event_type, data in extract_skills_from_cv_stream(content, user_id=str(current_user.id)):
            if event_type == "done":
                # Émettre chaque skill avec un délai pour l'effet visuel
                for skill in data:
                    yield f'event: skill\ndata: {json.dumps(skill)}\n\n'
                    await asyncio.sleep(0.15)
                yield 'event: complete\ndata: {"status":"done"}\n\n'
            elif event_type == "error":
                yield f'event: error\ndata: {json.dumps({"error": data})}\n\n'

    return StreamingResponse(_stream(), media_type="text/event-stream")


# Status endpoints

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


# Archive

@router.post("/archive")
async def archive_roadmap(
    current_user: User = Depends(get_current_user),
    svc: RoadmapService = Depends(get_roadmap_service),
):
    await svc.archive_active_roadmap(str(current_user.id))
    return {"message": "Roadmap archived"}


# Get roadmap

@router.get("", response_model=RoadmapResponse)
async def get_roadmap(
    current_user: User = Depends(get_current_user),
    svc: RoadmapService = Depends(get_roadmap_service),
):
    roadmap = await svc.get_active(str(current_user.id))
    return _roadmap_to_response(roadmap)


@router.get("/history", response_model=list[RoadmapHistoryItem])
async def roadmap_history(
    current_user: User = Depends(get_current_user),
    svc: RoadmapService = Depends(get_roadmap_service),
):
    roadmaps = await svc.get_history(str(current_user.id))
    return [_roadmap_to_response(r) for r in roadmaps]


@router.get("/{roadmap_id}", response_model=RoadmapResponse)
async def get_roadmap_by_id(
    roadmap_id: str,
    current_user: User = Depends(get_current_user),
    svc: RoadmapService = Depends(get_roadmap_service),
):
    roadmap = await svc.get_by_id(roadmap_id, str(current_user.id))
    return _roadmap_to_response(roadmap)


@router.post("/{roadmap_id}/restore", response_model=RoadmapResponse)
async def restore_roadmap(
    roadmap_id: str,
    current_user: User = Depends(get_current_user),
    svc: RoadmapService = Depends(get_roadmap_service),
):
    roadmap = await svc.restore_roadmap(roadmap_id, str(current_user.id))
    return _roadmap_to_response(roadmap)


# Suppression

@router.delete("/{roadmap_id}")
async def delete_roadmap(
    roadmap_id: str,
    current_user: User = Depends(get_current_user),
    svc: RoadmapService = Depends(get_roadmap_service),
):
    await svc.delete_roadmap(roadmap_id, str(current_user.id))
    return {"message": "Roadmap deleted"}


@router.delete("")
async def delete_all_roadmaps(
    current_user: User = Depends(get_current_user),
    svc: RoadmapService = Depends(get_roadmap_service),
):
    count = await svc.delete_all_archived(str(current_user.id))
    return {"message": f"{count} roadmap(s) deleted", "count": count}


# Phases

@router.post("/phases", response_model=PhaseResponse)
async def add_phase(
    body: PhaseCreate,
    current_user: User = Depends(get_current_user),
    svc: RoadmapService = Depends(get_roadmap_service),
):
    phase = await svc.add_phase(str(current_user.id), body)
    return _phase_to_dict(phase)


@router.put("/phases/{phase_id}", response_model=PhaseResponse)
async def update_phase(
    phase_id: str,
    body: PhaseUpdate,
    current_user: User = Depends(get_current_user),
    svc: RoadmapService = Depends(get_roadmap_service),
):
    phase = await svc.update_phase(phase_id, str(current_user.id), body.model_dump(exclude_none=True))
    return _phase_to_dict(phase)


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
    return _phase_to_dict(phase)


@router.patch("/phases/{phase_id}/actions/{action_index}/complete", response_model=PhaseResponse)
async def toggle_action_complete(
    phase_id: str,
    action_index: int,
    current_user: User = Depends(get_current_user),
    svc: RoadmapService = Depends(get_roadmap_service),
):
    phase = await svc.toggle_action_complete(phase_id, str(current_user.id), action_index)
    return _phase_to_dict(phase)


@router.patch("/phases/{phase_id}/skills/{skill_index}/complete", response_model=PhaseResponse)
async def toggle_skill_complete(
    phase_id: str,
    skill_index: int,
    current_user: User = Depends(get_current_user),
    svc: RoadmapService = Depends(get_roadmap_service),
):
    phase = await svc.toggle_skill_complete(phase_id, str(current_user.id), skill_index)
    return _phase_to_dict(phase)


@router.put("/phases/reorder")
async def reorder_phases(
    body: PhaseReorder,
    current_user: User = Depends(get_current_user),
    svc: RoadmapService = Depends(get_roadmap_service),
):
    await svc.reorder_phases(str(current_user.id), body.phase_ids)
    return {"ok": True}
