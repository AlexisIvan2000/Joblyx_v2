from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession
from core.database import get_db_session
from core.exceptions import AdminAccessRequired, SuperAdminAccessRequired
from services.admin.users_service import AdminUsersService
from services.admin.stats_service import AdminStatsService
from services.admin.audit_service import AdminAuditService
from services.admin.sentry_service import SentryService
from api.v1.client.dependencies import get_current_user


async def get_admin_users_service(session: AsyncSession = Depends(get_db_session)) -> AdminUsersService:
    return AdminUsersService(session)


async def get_admin_stats_service(session: AsyncSession = Depends(get_db_session)) -> AdminStatsService:
    return AdminStatsService(session)


async def get_admin_audit_service(session: AsyncSession = Depends(get_db_session)) -> AdminAuditService:
    return AdminAuditService(session)


def get_sentry_service() -> SentryService:
    return SentryService()

# Routes /admin/* exigent le rôle admin ou super_admin
async def require_admin(current_user=Depends(get_current_user)):
    if current_user.role not in ("admin", "super_admin"):
        raise AdminAccessRequired()
    return current_user

# # Actions critiques (modif d'un autre admin) réservées au super_admin
async def require_super_admin(current_user=Depends(get_current_user)):
    if current_user.role != "super_admin":
        raise SuperAdminAccessRequired()
    return current_user
