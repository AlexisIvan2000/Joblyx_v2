"""Routes pour l'assistant IA — regroupe coach et interview sous /assistant."""

from fastapi import APIRouter

from api.routers.coach import router as coach_router
from api.routers.interview import router as interview_router

router = APIRouter(prefix="/assistant", tags=["assistant"])

router.include_router(coach_router)
router.include_router(interview_router)
