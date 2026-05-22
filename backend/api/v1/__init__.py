from fastapi import APIRouter

from api.routers.admin import router as admin_router
from api.routers.applications import router as applications_router
from api.routers.assistant import router as assistant_router
from api.routers.auth import router as auth_router
from api.routers.roadmap import router as roadmap_router
from api.routers.users import router as users_router

v1_router = APIRouter(prefix="/v1")

v1_router.include_router(auth_router)
v1_router.include_router(users_router)
v1_router.include_router(roadmap_router)
v1_router.include_router(applications_router)
v1_router.include_router(assistant_router)
v1_router.include_router(admin_router)
