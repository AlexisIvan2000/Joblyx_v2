from fastapi import APIRouter, Depends, Query

from api.v1.admin.dependencies import get_sentry_service
from services.admin.sentry_service import SentryService

router = APIRouter(tags=["admin"])


# Proxy vers l'API Sentry pour la page Erreurs du panel admin

@router.get("/sentry/issues")
async def sentry_list_issues(
    query: str = Query("is:unresolved"),
    cursor: str | None = None,
    limit: int = Query(25, ge=1, le=100),
    environment: str | None = None,
    sentry: SentryService = Depends(get_sentry_service),
):
    return await sentry.list_issues(
        query=query, cursor=cursor, limit=limit, environment=environment,
    )


@router.get("/sentry/issues/{issue_id}")
async def sentry_issue_detail(
    issue_id: str,
    sentry: SentryService = Depends(get_sentry_service),
):
    return await sentry.get_issue(issue_id)


@router.get("/sentry/issues/{issue_id}/events")
async def sentry_issue_events(
    issue_id: str,
    limit: int = Query(10, ge=1, le=50),
    sentry: SentryService = Depends(get_sentry_service),
):
    return await sentry.get_issue_events(issue_id, limit=limit)
