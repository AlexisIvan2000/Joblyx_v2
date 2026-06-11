from fastapi import APIRouter

from api.v1.admin import router as admin_router
from api.v1.client import router as client_router

# API versionnée, toutes les nouvelles intégrations pointent vers /v1/...
v1_router = APIRouter(prefix="/v1")
v1_router.include_router(client_router)
v1_router.include_router(admin_router)
