import copy

from fastapi import APIRouter, Depends, File, HTTPException, Request, UploadFile, status
from fastapi.responses import StreamingResponse
from sqlalchemy import update as sa_update, delete as sa_delete
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
from models.db_models import User, Career, UserSkill
from api.dependencies import get_current_user, get_roadmap_service
from services.roadmap.roadmap_service import RoadmapService
from services.ai.cv_parser import extract_skills_from_cv

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


# ─── Generate (SSE streaming) ────────────────────────────────────

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
        regen = await svc.check_regeneration_limit(user_id)
        if not regen["allowed"]:
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail={
                    "error": "Vous avez atteint la limite de 5 regenerations ce mois-ci",
                    "remaining": 0,
                    "resets_at": regen["resets_at"],
                },
            )

    async def _stream():
        async for event in svc.generate_stream(user_id):
            yield event

    return StreamingResponse(_stream(), media_type="text/event-stream")


# ─── Regenerate (no body — uses existing career data) ─────────

@router.post("/regenerate")
@limiter.limit("3/minute", key_func=get_user_id_from_jwt)
async def regenerate_roadmap(
    request: Request,
    current_user: User = Depends(get_current_user),
    svc: RoadmapService = Depends(get_roadmap_service),
):
    user_id = str(current_user.id)

    career = await svc._get_career(user_id)
    if not career:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Career profile not found. Complete onboarding first.",
        )

    regen = await svc.check_regeneration_limit(user_id)
    if not regen["allowed"]:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail={
                "error": "Vous avez atteint la limite de 5 regenerations ce mois-ci",
                "remaining": 0,
                "resets_at": regen["resets_at"],
            },
        )

    async def _stream():
        async for event in svc.generate_stream(user_id):
            yield event

    return StreamingResponse(_stream(), media_type="text/event-stream")


# ─── Career profile (get / update) ───────────────────────────

@router.get("/career", response_model=CareerProfileResponse)
async def get_career_profile(
    current_user: User = Depends(get_current_user),
    svc: RoadmapService = Depends(get_roadmap_service),
):
    user_id = str(current_user.id)
    career = await svc._get_career(user_id)
    if not career:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Career profile not found")

    skills = await svc._get_skills(user_id)
    return {
        "level": career.level,
        "years_experience": career.years_experience,
        "target_jobs": career.target_jobs or [],
        "city": career.city,
        "province": career.province,
        "language": career.language,
        "previous_field": career.previous_field,
        "skills": skills,
    }


@router.put("/career", response_model=CareerProfileResponse)
async def update_career_profile(
    body: CareerProfileUpdate,
    current_user: User = Depends(get_current_user),
    svc: RoadmapService = Depends(get_roadmap_service),
):
    user_id = str(current_user.id)
    career = await svc._get_career(user_id)

    # Build career update dict from non-None fields (excluding skills)
    career_updates = {}
    for field in ("level", "years_experience", "target_jobs", "city", "province", "language", "previous_field"):
        val = getattr(body, field, None)
        if val is not None:
            career_updates[field] = val.value if hasattr(val, "value") else val

    if not career:
        # Create career profile for new users
        svc.session.add(Career(user_id=user_id, **career_updates))
        await svc.session.flush()
    elif career_updates:
        await svc.session.execute(
            sa_update(Career).where(Career.user_id == user_id).values(**career_updates)
        )

    # Update skills if provided
    if body.skills is not None:
        skills_data = [
            {"skill_name": s.skill_name, "category": s.category, "proficiency": s.proficiency.value}
            for s in body.skills
        ]
        await svc.session.execute(
            sa_delete(UserSkill).where(UserSkill.user_id == user_id)
        )
        if skills_data:
            svc.session.add_all([UserSkill(user_id=user_id, **s) for s in skills_data])
        await svc.session.flush()

    await svc.session.commit()

    # Return updated data
    career = await svc._get_career(user_id)
    skills = await svc._get_skills(user_id)
    return {
        "level": career.level,
        "years_experience": career.years_experience,
        "target_jobs": career.target_jobs or [],
        "city": career.city,
        "province": career.province,
        "language": career.language,
        "previous_field": career.previous_field,
        "skills": skills,
    }


# Création manuelle

@router.post("/manual", response_model=RoadmapResponse)
async def create_manual_roadmap(
    body: RoadmapCreate,
    current_user: User = Depends(get_current_user),
    svc: RoadmapService = Depends(get_roadmap_service),
):
    user_id = str(current_user.id)
    await svc.repo.archive_active(user_id)

    roadmap = await svc.repo.create_roadmap(user_id)

    phases_data = []
    for i, p in enumerate(body.phases):
        phase_dict = p.model_dump(exclude={"position"})
        phase_dict["phase_number"] = i + 1
        phase_dict["completed"] = False
        phase_dict["custom"] = True
        phase_dict["position"] = i
        phases_data.append(phase_dict)

    await svc.repo.create_phases(roadmap.id, phases_data)
    await svc.session.commit()

    # Reload with phases
    roadmap = await svc.repo.get_active_roadmap(user_id)
    return _roadmap_to_response(roadmap)


# ─── Extract skills ──────────────────────────────────────────────

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

    skills = await extract_skills_from_cv(content)
    return {"skills": skills}


# ─── Status endpoints ────────────────────────────────────────────

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
    career = await svc._get_career(str(current_user.id))
    roadmap = await svc.repo.get_active_roadmap(str(current_user.id))
    return {
        "generation_status": career.generation_status if career else "idle",
        "has_roadmap": roadmap is not None,
    }


# ─── Get roadmap ─────────────────────────────────────────────────

@router.get("", response_model=RoadmapResponse)
async def get_roadmap(
    current_user: User = Depends(get_current_user),
    svc: RoadmapService = Depends(get_roadmap_service),
):
    roadmap = await svc.repo.get_active_roadmap(str(current_user.id))
    if not roadmap:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="No active roadmap")
    return _roadmap_to_response(roadmap)


@router.get("/history", response_model=list[RoadmapHistoryItem])
async def roadmap_history(
    current_user: User = Depends(get_current_user),
    svc: RoadmapService = Depends(get_roadmap_service),
):
    roadmaps = await svc.repo.get_history(str(current_user.id))
    return [_roadmap_to_response(r) for r in roadmaps]


@router.get("/{roadmap_id}", response_model=RoadmapResponse)
async def get_roadmap_by_id(
    roadmap_id: str,
    current_user: User = Depends(get_current_user),
    svc: RoadmapService = Depends(get_roadmap_service),
):
    roadmap = await svc.repo.get_by_id(roadmap_id, str(current_user.id))
    if not roadmap:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Roadmap not found")
    return _roadmap_to_response(roadmap)


@router.post("/{roadmap_id}/restore", response_model=RoadmapResponse)
async def restore_roadmap(
    roadmap_id: str,
    current_user: User = Depends(get_current_user),
    svc: RoadmapService = Depends(get_roadmap_service),
):
    roadmap = await svc.repo.restore(roadmap_id, str(current_user.id))
    if not roadmap:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Roadmap not found or not archived")
    await svc.session.commit()
    return _roadmap_to_response(roadmap)


# ─── Phase endpoints ─────────────────────────────────────────────

@router.post("/phases", response_model=PhaseResponse)
async def add_phase(
    body: PhaseCreate,
    current_user: User = Depends(get_current_user),
    svc: RoadmapService = Depends(get_roadmap_service),
):
    user_id = str(current_user.id)
    roadmap = await svc.repo.get_active_roadmap(user_id)
    if not roadmap:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="No active roadmap")

    position = body.position if body.position is not None else len(roadmap.phases)
    phase_data = body.model_dump(exclude={"position"})
    phase_data["phase_number"] = position + 1

    phase = await svc.repo.add_phase(roadmap.id, phase_data, position)
    await svc.session.commit()
    return _phase_to_dict(phase)


@router.put("/phases/{phase_id}", response_model=PhaseResponse)
async def update_phase(
    phase_id: str,
    body: PhaseUpdate,
    current_user: User = Depends(get_current_user),
    svc: RoadmapService = Depends(get_roadmap_service),
):
    phase = await svc.repo.get_phase(phase_id, str(current_user.id))
    if not phase:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Phase not found")

    data = body.model_dump(exclude_none=True)
    if not data:
        return _phase_to_dict(phase)

    phase = await svc.repo.update_phase(phase_id, data)
    await svc.session.commit()
    return _phase_to_dict(phase)


@router.delete("/phases/{phase_id}", status_code=204)
async def delete_phase(
    phase_id: str,
    current_user: User = Depends(get_current_user),
    svc: RoadmapService = Depends(get_roadmap_service),
):
    phase = await svc.repo.get_phase(phase_id, str(current_user.id))
    if not phase:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Phase not found")

    await svc.repo.delete_phase(phase_id)
    await svc.session.commit()


@router.patch("/phases/{phase_id}/complete", response_model=PhaseResponse)
async def toggle_phase_complete(
    phase_id: str,
    current_user: User = Depends(get_current_user),
    svc: RoadmapService = Depends(get_roadmap_service),
):
    phase = await svc.repo.get_phase(phase_id, str(current_user.id))
    if not phase:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Phase not found")

    phase = await svc.repo.toggle_phase_complete(phase_id)
    await svc.session.commit()
    return _phase_to_dict(phase)


@router.patch("/phases/{phase_id}/actions/{action_index}/complete", response_model=PhaseResponse)
async def toggle_action_complete(
    phase_id: str,
    action_index: int,
    current_user: User = Depends(get_current_user),
    svc: RoadmapService = Depends(get_roadmap_service),
):
    phase = await svc.repo.get_phase(phase_id, str(current_user.id))
    if not phase:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Phase not found")

    actions = copy.deepcopy(phase.actions or [])
    if action_index < 0 or action_index >= len(actions):
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Action not found")

    actions[action_index]["completed"] = not actions[action_index].get("completed", False)
    phase = await svc.repo.update_phase(phase_id, {"actions": actions})
    await svc.session.commit()
    return _phase_to_dict(phase)


@router.patch("/phases/{phase_id}/skills/{skill_index}/complete", response_model=PhaseResponse)
async def toggle_skill_complete(
    phase_id: str,
    skill_index: int,
    current_user: User = Depends(get_current_user),
    svc: RoadmapService = Depends(get_roadmap_service),
):
    phase = await svc.repo.get_phase(phase_id, str(current_user.id))
    if not phase:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Phase not found")

    skills = copy.deepcopy(phase.skills or [])
    if skill_index < 0 or skill_index >= len(skills):
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Skill not found")

    skills[skill_index]["completed"] = not skills[skill_index].get("completed", False)
    phase = await svc.repo.update_phase(phase_id, {"skills": skills})
    await svc.session.commit()
    return _phase_to_dict(phase)


@router.put("/phases/reorder")
async def reorder_phases(
    body: PhaseReorder,
    current_user: User = Depends(get_current_user),
    svc: RoadmapService = Depends(get_roadmap_service),
):
    user_id = str(current_user.id)
    roadmap = await svc.repo.get_active_roadmap(user_id)
    if not roadmap:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="No active roadmap")

    # Verifie que tous les phase_ids fournis appartiennent à la roadmap active de l'utilisateur
    roadmap_phase_ids = {str(p.id) for p in roadmap.phases}
    if set(body.phase_ids) != roadmap_phase_ids:
        raise HTTPException(status_code=400, detail="phase_ids must match all phases of the active roadmap")

    await svc.repo.reorder_phases(roadmap.id, body.phase_ids)
    await svc.session.commit()
    return {"ok": True}
