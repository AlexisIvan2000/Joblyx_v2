from fastapi import APIRouter
from api.v1.client.coach import router as coach_router
from api.v1.client.interview import router as interview_router

router = APIRouter(prefix="/assistant", tags=["assistant"])

router.include_router(coach_router)
router.include_router(interview_router)
