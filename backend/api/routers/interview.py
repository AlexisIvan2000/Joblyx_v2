"""Routes REST + WebSocket pour le simulateur d'entretien."""

import json
import logging

import fitz

from fastapi import APIRouter, Depends, File, Form, HTTPException, Query, Request, UploadFile, WebSocket, WebSocketDisconnect
from pydantic import BaseModel

from api.dependencies import get_current_user
from core.database import get_db_session
from core.rate_limit import limiter, get_user_id_from_jwt
from core.security import Security
from models.db_models import User
from repositories.auth_repository import AuthRepository
from services.interview.interview_service import InterviewService
from services.utils.job_title_validator import validate_job_title
from sqlalchemy.ext.asyncio import AsyncSession

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/interview", tags=["interview"])


async def get_interview_service(session: AsyncSession = Depends(get_db_session)) -> InterviewService:
    return InterviewService(session)


# Schemas 

# Démarrer un entretien 

@router.post("/start")
@limiter.limit("3/minute", key_func=get_user_id_from_jwt)
async def start_interview(
    request: Request,
    job_title: str = Form(...),
    company_name: str = Form(None),
    job_description: str = Form(None),
    language: str = Form("fr"),
    cv_file: UploadFile | None = File(None),
    current_user: User = Depends(get_current_user),
    svc: InterviewService = Depends(get_interview_service),
):
    # Valider que le titre de poste est lié à l'IT
    job_title = validate_job_title(job_title)

    # Extraire le texte du CV si fourni
    cv_text = None
    if cv_file:
        if not cv_file.content_type or "pdf" not in cv_file.content_type:
            raise HTTPException(status_code=400, detail="Only PDF files are accepted")
        cv_bytes = await cv_file.read()
        if len(cv_bytes) > 10 * 1024 * 1024:
            raise HTTPException(status_code=400, detail="File too large (max 10 MB)")
        # Parser le PDF en texte
        doc = fitz.open(stream=cv_bytes, filetype="pdf")
        cv_text = ""
        for page in doc:
            cv_text += page.get_text()
        doc.close()
        cv_text = cv_text.strip() or None

    return await svc.start_session(
        user_id=str(current_user.id),
        job_title=job_title,
        company_name=company_name,
        job_description=job_description,
        cv_text=cv_text,
        language=language,
    )


#  Terminer en avance

@router.post("/{session_id}/end")
async def end_interview(
    session_id: str,
    current_user: User = Depends(get_current_user),
    svc: InterviewService = Depends(get_interview_service),
):
    return await svc.end_session_early(session_id, str(current_user.id))


#  Usage
@router.get("/usage")
async def get_usage(
    current_user: User = Depends(get_current_user),
    svc: InterviewService = Depends(get_interview_service),
):
    return await svc.check_usage(str(current_user.id))


#  Historique 

@router.get("/history")
async def get_history(
    current_user: User = Depends(get_current_user),
    svc: InterviewService = Depends(get_interview_service),
):
    sessions = await svc.get_history(str(current_user.id))
    result = []
    for s in sessions:
        # Dernier message pour l'aperçu
        last_msg = s.messages[-1].content if s.messages else None
        if last_msg and len(last_msg) > 80:
            last_msg = last_msg[:80] + "..."
        result.append({
            "id": str(s.id),
            "job_title": s.job_title,
            "company_name": s.company_name,
            "status": s.status,
            "overall_score": s.overall_score,
            "last_message": last_msg,
            "created_at": s.created_at.isoformat() if s.created_at else None,
        })
    return result


# Détail (session_id APRÈS les routes nommées)

@router.get("/{session_id}")
async def get_session(
    session_id: str,
    current_user: User = Depends(get_current_user),
    svc: InterviewService = Depends(get_interview_service),
):
    s = await svc.get_session(session_id, str(current_user.id))
    return {
        "id": str(s.id),
        "job_title": s.job_title,
        "company_name": s.company_name,
        "job_description": s.job_description,
        "status": s.status,
        "language": s.language,
        "overall_score": s.overall_score,
        "category_scores": s.category_scores,
        "summary": s.summary,
        "created_at": s.created_at.isoformat() if s.created_at else None,
        "completed_at": s.completed_at.isoformat() if s.completed_at else None,
        "messages": [
            {
                "id": str(m.id),
                "role": m.role,
                "content": m.content,
                "feedback": m.feedback,
                "position": m.position,
            }
            for m in s.messages
        ],
    }


# Bilan seul 

@router.get("/{session_id}/summary")
async def get_summary(
    session_id: str,
    current_user: User = Depends(get_current_user),
    svc: InterviewService = Depends(get_interview_service),
):
    s = await svc.get_session(session_id, str(current_user.id))
    if s.status != "completed":
        raise HTTPException(status_code=400, detail="Interview not completed yet")
    return {
        "overall_score": s.overall_score,
        "category_scores": s.category_scores,
        "summary": s.summary,
    }


#  Suppression 

@router.delete("/{session_id}")
async def delete_session(
    session_id: str,
    current_user: User = Depends(get_current_user),
    svc: InterviewService = Depends(get_interview_service),
):
    await svc.delete_session(session_id, str(current_user.id))
    return {"message": "Session deleted"}


@router.delete("")
async def delete_all_sessions(
    current_user: User = Depends(get_current_user),
    svc: InterviewService = Depends(get_interview_service),
):
    count = await svc.delete_all(str(current_user.id))
    return {"message": f"{count} session(s) deleted", "count": count}


#  WebSocket 

@router.websocket("/ws/{session_id}")
async def interview_ws(
    websocket: WebSocket,
    session_id: str,
    token: str = Query(...),
):
    """WebSocket pour le chat d'entretien en temps réel avec streaming."""
    # Authentifier via le token JWT
    payload = Security.decode_token(token)
    if not payload or payload.get("type") != "access":
        await websocket.close(code=4001, reason="Invalid token")
        return

    user_id = payload.get("sub")
    if not user_id:
        await websocket.close(code=4001, reason="Invalid token")
        return

    # Obtenir une session DB
    from core.database import async_session_factory
    async with async_session_factory() as db_session:
        svc = InterviewService(db_session)

        # Vérifier que la session existe et appartient au user
        interview = await svc.repo.get_session_by_id(session_id, user_id)
        if not interview:
            await websocket.close(code=4004, reason="Session not found")
            return
        if interview.status != "in_progress":
            await websocket.close(code=4003, reason="Session completed")
            return

        await websocket.accept()

        try:
            while True:
                # Recevoir le message du candidat
                data = await websocket.receive_text()

                try:
                    msg_data = json.loads(data)
                    user_message = msg_data.get("message", "")
                except (json.JSONDecodeError, AttributeError):
                    user_message = data

                # Streamer la réponse
                async for event_type, event_data in svc.send_message_stream(
                    session_id, user_id, user_message
                ):
                    if event_type == "stream":
                        await websocket.send_json({
                            "type": "stream",
                            "text": event_data,
                        })
                    elif event_type == "stream_end":
                        await websocket.send_json({"type": "stream_end"})
                    elif event_type == "feedback":
                        await websocket.send_json({
                            "type": "feedback",
                            "data": event_data,
                        })
                    elif event_type == "summary":
                        await websocket.send_json({
                            "type": "summary",
                            "data": event_data,
                        })
                        # Fermer après le bilan
                        await websocket.close(code=1000, reason="Interview completed")
                        return
                    elif event_type == "error":
                        await websocket.send_json({
                            "type": "error",
                            "message": event_data,
                        })

        except WebSocketDisconnect:
            logger.info("WebSocket disconnected: session_id=%s", session_id)
            # La session reste in_progress, reprise possible
        except Exception as e:
            logger.exception("WebSocket error: session_id=%s", session_id)
            try:
                await websocket.send_json({"type": "error", "message": str(e)})
            except Exception:
                pass
