from fastapi import APIRouter, Depends

from api.v1.admin.dependencies import require_admin
from api.v1.admin.audit import router as audit_router
from api.v1.admin.sentry import router as sentry_router
from api.v1.admin.stats import router as stats_router
from api.v1.admin.users import router as users_router

# Router admin agrégé, protégé globalement par require_admin
router = APIRouter(prefix="/admin", dependencies=[Depends(require_admin)])
router.include_router(stats_router)
router.include_router(users_router)
router.include_router(audit_router)
router.include_router(sentry_router)
