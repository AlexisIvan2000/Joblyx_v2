import json

from fastapi import APIRouter, Depends, File, Form, Request, UploadFile
from core.uploads import validate_pdf, PDF_MAX_BYTES_LARGE
from fastapi.responses import StreamingResponse
from api.v1.client.dependencies import get_current_user
from core.database import get_db_session
from core.rate_limit import limiter, get_user_id_from_jwt
from models.db_models import User
from services.coach.coach_service import CoachService
from services.utils.job_title_validator import validate_job_title
from sqlalchemy.ext.asyncio import AsyncSession

router = APIRouter(prefix="/coach", tags=["coach"])


async def get_coach_service(session: AsyncSession = Depends(get_db_session)) -> CoachService:
    return CoachService(session)


# Analyse coach IA (SSE streaming)

@router.post("/analyze")
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
    # Valider que le titre de poste est lié à l'IT
    if job_title:
        job_title = validate_job_title(job_title)

    cv_bytes = await cv_file.read()
    validate_pdf(cv_file.content_type, len(cv_bytes), max_bytes=PDF_MAX_BYTES_LARGE)

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


#  Historique 

@router.get("/history")
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


# Usage (AVANT {session_id} pour éviter le conflit) 

@router.get("/usage")
async def get_usage(
    current_user: User = Depends(get_current_user),
    svc: CoachService = Depends(get_coach_service),
):
    return await svc.check_usage(str(current_user.id))


# Détail d'une session

@router.get("/{session_id}")
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


# Suppression 

@router.delete("/{session_id}")
async def delete_session(
    session_id: str,
    current_user: User = Depends(get_current_user),
    svc: CoachService = Depends(get_coach_service),
):
    await svc.delete_session(session_id, str(current_user.id))
    return {"message": "Session deleted"}


@router.delete("")
async def delete_all_sessions(
    current_user: User = Depends(get_current_user),
    svc: CoachService = Depends(get_coach_service),
):
    count = await svc.delete_all(str(current_user.id))
    return {"message": f"{count} session(s) deleted", "count": count}
