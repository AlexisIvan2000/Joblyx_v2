from fastapi import APIRouter, Depends, Query

from api.v1.admin.dependencies import get_admin_stats_service
from services.admin.stats_service import AdminStatsService
from models.api_schemas import AdminRegistrationPoint, AdminStatsResponse

router = APIRouter(tags=["admin"])


@router.get("/stats", response_model=AdminStatsResponse)
async def get_stats(svc: AdminStatsService = Depends(get_admin_stats_service)):
    return await svc.get_dashboard_stats()


@router.get("/stats/registrations", response_model=list[AdminRegistrationPoint])
async def get_registrations(
    period: str = Query("week", pattern="^(week|month)$"),
    svc: AdminStatsService = Depends(get_admin_stats_service),
):
    return await svc.get_registrations(period)
