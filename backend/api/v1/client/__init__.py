from fastapi import APIRouter

from api.v1.client.auth import router as auth_router
from api.v1.client.users import router as users_router
from api.v1.client.roadmap import router as roadmap_router
from api.v1.client.applications import router as applications_router
from api.v1.client.assistant import router as assistant_router

# Router des routes utilisateur, assistant regroupe coach et interview sous /assistant
router = APIRouter()
router.include_router(auth_router)
router.include_router(users_router)
router.include_router(roadmap_router)
router.include_router(applications_router)
router.include_router(assistant_router)
