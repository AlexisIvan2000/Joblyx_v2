"""Routes pour l'assistant IA (coach CV + futur simulateur d'entretien)."""

import json

from fastapi import APIRouter, Depends, File, Form, HTTPException, Request, UploadFile
from fastapi.responses import StreamingResponse

from api.dependencies import get_current_user
from core.database import get_db_session
from core.rate_limit import limiter, get_user_id_from_jwt
from models.db_models import User
from repositories.coach_repository import CoachRepository
from services.coach.coach_service import CoachService
from sqlalchemy.ext.asyncio import AsyncSession

router = APIRouter(prefix="/assistant", tags=["assistant"])


async def get_coach_service(session: AsyncSession = Depends(get_db_session)) -> CoachService:
    return CoachService(session)


# ─── Analyse coach IA (SSE streaming) ───────────────────────────

@router.post("/coach/analyze")
@limiter.limit("5/minute", key_func=get_user_id_from_jwt)
async def analyze(
    request: Request,
    cv_file: UploadFile = File(...),
    job_description: str = Form(...),
    job_title: str = Form(None),
    company_name: str = Form(None),
    language: str = Form("fr"),
    current_user: User = Depends(get_current_user),
    svc: CoachService = Depends(get_coach_service),
):
    # Validation PDF
    if not cv_file.content_type or "pdf" not in cv_file.content_type:
        raise HTTPException(status_code=400, detail="Only PDF files are accepted")

    cv_bytes = await cv_file.read()
    if len(cv_bytes) > 10 * 1024 * 1024:
        raise HTTPException(status_code=400, detail="File too large (max 10 MB)")

    user_id = str(current_user.id)

    async def _stream():
        yield 'event: status\ndata: {"status":"analyzing"}\n\n'
        async for event_type, data in svc.analyze_stream(
            user_id=user_id,
            cv_bytes=cv_bytes,
            cv_filename=cv_file.filename or "cv.pdf",
            job_description=job_description,
            job_title=job_title,
            company_name=company_name,
            language=language,
        ):
            if event_type == "chunk":
                yield f'event: chunk\ndata: {json.dumps({"text": data})}\n\n'
            elif event_type == "done":
                yield f'event: analysis\ndata: {json.dumps(data)}\n\n'
                yield 'event: complete\ndata: {"status":"done"}\n\n'
            elif event_type == "error":
                yield f'event: error\ndata: {json.dumps({"error": data})}\n\n'

    return StreamingResponse(_stream(), media_type="text/event-stream")


# ─── Historique ──────────────────────────────────────────────────

@router.get("/coach/history")
async def get_history(
    current_user: User = Depends(get_current_user),
    svc: CoachService = Depends(get_coach_service),
):
    sessions = await svc.get_history(str(current_user.id))
    return [
        {
            "id": str(s.id),
            "job_title": s.job_title,
            "company_name": s.company_name,
            "compatibility_score": s.compatibility_score,
            "created_at": s.created_at.isoformat() if s.created_at else None,
        }
        for s in sessions
    ]


# ─── Détail d'une session ───────────────────────────────────────

@router.get("/coach/{session_id}")
async def get_session(
    session_id: str,
    current_user: User = Depends(get_current_user),
    svc: CoachService = Depends(get_coach_service),
):
    s = await svc.get_session(session_id, str(current_user.id))
    return {
        "id": str(s.id),
        "job_title": s.job_title,
        "company_name": s.company_name,
        "job_description": s.job_description,
        "compatibility_score": s.compatibility_score,
        "analysis": s.analysis,
        "language": s.language,
        "created_at": s.created_at.isoformat() if s.created_at else None,
    }


# ─── Suppression ────────────────────────────────────────────────

@router.delete("/coach/{session_id}")
async def delete_session(
    session_id: str,
    current_user: User = Depends(get_current_user),
    svc: CoachService = Depends(get_coach_service),
):
    await svc.delete_session(session_id, str(current_user.id))
    return {"message": "Session deleted"}


@router.delete("/coach")
async def delete_all_sessions(
    current_user: User = Depends(get_current_user),
    svc: CoachService = Depends(get_coach_service),
):
    count = await svc.delete_all(str(current_user.id))
    return {"message": f"{count} session(s) deleted", "count": count}


# ─── Usage ───────────────────────────────────────────────────────

@router.get("/coach/usage")
async def get_usage(
    current_user: User = Depends(get_current_user),
    svc: CoachService = Depends(get_coach_service),
):
    return await svc.check_usage(str(current_user.id))
