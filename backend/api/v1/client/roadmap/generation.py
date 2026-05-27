import asyncio
import json

from fastapi import APIRouter, Depends, File, Request, UploadFile
from fastapi.responses import StreamingResponse

from core.uploads import validate_pdf
from core.rate_limit import limiter, get_user_id_from_jwt
from models.schemas import RoadmapGenerateRequest
from models.db_models import User
from api.v1.client.dependencies import get_current_user, get_roadmap_service
from services.roadmap.roadmap_service import RoadmapService
from services.ai.cv_parser import extract_skills_from_cv_stream

router = APIRouter(tags=["roadmap"])


# Génération initiale (SSE streaming)
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


# Régénération (sans body, utilise les données career existantes)
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


# Extraction de skills depuis un CV (SSE streaming)
@router.post("/extract-skills")
@limiter.limit("5/minute", key_func=get_user_id_from_jwt)
async def extract_skills(
    request: Request,
    file: UploadFile = File(...),
    current_user: User = Depends(get_current_user),
):
    content = await file.read()
    validate_pdf(file.content_type, len(content))

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
