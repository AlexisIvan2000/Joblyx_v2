from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from api.dependencies import (
    get_admin_audit_service,
    get_admin_stats_service,
    get_admin_users_service,
    get_r2_service,
    get_sentry_service,
    require_admin,
    require_super_admin,
)
from core.config import ADMIN_EMAIL
from core.database import get_db_session
from models.db_models import User
from services.admin.audit_service import AdminAuditService
from services.admin.sentry_service import SentryService
from services.admin.stats_service import AdminStatsService
from services.admin.users_service import AdminUsersService
from models.api_schemas import (
    AdminApplicationSummary,
    AdminAuditLogResponse,
    AdminCareerSummary,
    AdminCoachSessionSummary,
    AdminInterviewSessionSummary,
    AdminRegistrationPoint,
    AdminRoadmapSummary,
    AdminSkillSummary,
    AdminStatsResponse,
    AdminStatusRequest,
    AdminUserActionResponse,
    AdminUserDetailResponse,
    AdminUserListResponse,
    AdminUserSummary,
    AdminUserUsage,
)
from models.api_schemas.admin import AdminEmailRequest, AdminNotesRequest
from repositories.application_repository import ApplicationRepository
from repositories.coach_repository import CoachRepository
from services.storage.r2_service import R2Service


router = APIRouter(
    prefix="/admin",
    tags=["admin"],
    dependencies=[Depends(require_admin)],
)


# Helpers de conversion (modèles SQLAlchemy → dicts pour DTOs)

def _is_founder(user) -> bool:
    return bool(ADMIN_EMAIL and user.email == ADMIN_EMAIL)


def _user_summary(user, stats: dict) -> dict:
    return {
        "id": str(user.id),
        "first_name": user.first_name,
        "last_name": user.last_name,
        "email": user.email,
        "is_verified": user.is_verified,
        "is_active": user.is_active,
        "has_linkedin": user.linkedin_id is not None,
        "role": user.role,
        "is_founder": _is_founder(user),
        "created_at": user.created_at.isoformat() if user.created_at else "",
        "last_active": user.updated_at.isoformat() if user.updated_at else None,
        "roadmaps_count": stats["roadmaps"],
        "applications_count": stats["applications"],
        "coach_sessions_count": stats["coach_sessions"],
        "interview_sessions_count": stats["interview_sessions"],
    }


def _career_summary(career) -> dict | None:
    if not career:
        return None
    return {
        "level": career.level,
        "years_experience": career.years_experience,
        "target_jobs": career.target_jobs or [],
        "city": career.city,
        "province": career.province,
        "language": career.language,
        "previous_field": career.previous_field,
        "generation_status": career.generation_status,
        "regeneration_count": career.regeneration_count or 0,
    }


def _roadmap_summary(roadmap) -> dict | None:
    if not roadmap:
        return None
    phases = roadmap.phases or []
    return {
        "id": str(roadmap.id),
        "status": roadmap.status,
        "phase_count": len(phases),
        "completed_phase_count": sum(1 for p in phases if p.completed),
        "created_at": roadmap.created_at.isoformat() if roadmap.created_at else None,
    }


def _application_summary(app) -> dict:
    return {
        "id": str(app.id),
        "company_name": app.company_name,
        "job_title": app.job_title,
        "status": app.status,
        "has_cv": app.cv_file_key is not None,
        "applied_at": app.applied_at.isoformat() if app.applied_at else None,
    }


def _coach_session_summary(s) -> dict:
    return {
        "id": str(s.id),
        "job_title": s.job_title,
        "company_name": s.company_name,
        "compatibility_score": s.compatibility_score,
        "created_at": s.created_at.isoformat() if s.created_at else None,
    }


def _interview_session_summary(s) -> dict:
    return {
        "id": str(s.id),
        "job_title": s.job_title,
        "company_name": s.company_name,
        "status": s.status,
        "overall_score": s.overall_score,
        "created_at": s.created_at.isoformat() if s.created_at else None,
    }


# Dashboard stats

@router.get("/stats", response_model=AdminStatsResponse)
async def get_stats(svc: AdminStatsService = Depends(get_admin_stats_service)):
    return await svc.get_dashboard_stats()


@router.get("/stats/registrations", response_model=list[AdminRegistrationPoint])
async def get_registrations(
    period: str = Query("week", pattern="^(week|month)$"),
    svc: AdminStatsService = Depends(get_admin_stats_service),
):
    return await svc.get_registrations(period)


# Gestion utilisateurs

@router.get("/users", response_model=AdminUserListResponse)
async def list_users(
    search: str | None = None,
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=100),
    is_active: bool | None = None,
    verified: bool | None = None,
    role: str | None = None,
    svc: AdminUsersService = Depends(get_admin_users_service),
):
    result = await svc.list_users(
        page=page, page_size=limit,
        search=search, is_active=is_active, verified=verified, role=role,
    )
    return {
        "users": [_user_summary(item["user"], item["stats"]) for item in result["users"]],
        "total": result["total"],
        "page": result["page"],
        "page_size": result["page_size"],
    }


@router.get("/users/{user_id}", response_model=AdminUserDetailResponse)
async def get_user_detail(user_id: str, svc: AdminUsersService = Depends(get_admin_users_service)):
    detail = await svc.get_user_detail(user_id)
    user = detail["user"]
    return {
        "id": str(user.id),
        "first_name": user.first_name,
        "last_name": user.last_name,
        "email": user.email,
        "is_verified": user.is_verified,
        "is_active": user.is_active,
        "has_linkedin": user.linkedin_id is not None,
        "avatar_url": user.avatar_url,
        "role": user.role,
        "deactivated_at": user.deactivated_at.isoformat() if user.deactivated_at else None,
        "deactivation_reason": user.deactivation_reason,
        "admin_notes": user.admin_notes,
        "is_founder": _is_founder(user),
        "created_at": user.created_at.isoformat() if user.created_at else "",
        "last_active": user.updated_at.isoformat() if user.updated_at else None,
        "career": _career_summary(detail["career"]),
        "skills": [
            {"skill_name": s.skill_name, "category": s.category, "proficiency": s.proficiency}
            for s in detail["skills"]
        ],
        "active_roadmap": _roadmap_summary(detail["active_roadmap"]),
        "applications": [_application_summary(a) for a in detail["applications"]],
        "coach_history": [_coach_session_summary(c) for c in detail["coach_sessions"]],
        "interview_history": [_interview_session_summary(i) for i in detail["interview_sessions"]],
        "usage": {
            "coach_usage_count": user.coach_usage_count or 0,
            "interview_usage_count": user.interview_usage_count or 0,
            "regeneration_count": detail["career"].regeneration_count if detail["career"] else 0,
        },
    }


@router.patch("/users/{user_id}/status", response_model=AdminUserActionResponse)
async def update_user_status(
    user_id: str,
    body: AdminStatusRequest,
    admin: User = Depends(require_admin),
    svc: AdminUsersService = Depends(get_admin_users_service),
):
    user = await svc.set_user_status(
        user_id, body.is_active, body.reason,
        admin_id=str(admin.id), caller_role=admin.role,
    )
    return {
        "id": str(user.id),
        "is_active": user.is_active,
        "deactivated_at": user.deactivated_at.isoformat() if user.deactivated_at else None,
        "deactivation_reason": user.deactivation_reason,
        "message": "User activated" if user.is_active else "User deactivated",
    }


@router.patch("/users/{user_id}/reset-limits")
async def reset_user_limits(
    user_id: str,
    admin: User = Depends(require_admin),
    svc: AdminUsersService = Depends(get_admin_users_service),
):
    await svc.reset_user_limits(user_id, admin_id=str(admin.id), caller_role=admin.role)
    return {"message": "Usage limits reset successfully"}


@router.post("/users/{user_id}/email")
async def send_email_to_user(
    user_id: str,
    body: AdminEmailRequest,
    admin: User = Depends(require_super_admin),
    svc: AdminUsersService = Depends(get_admin_users_service),
):
    """Envoie un email custom (texte brut) à un user, réservé au super_admin."""
    await svc.send_email(
        user_id, body.subject, body.body,
        admin_id=str(admin.id), caller_role=admin.role,
    )
    return {"message": "Email sent"}


@router.patch("/users/{user_id}/notes")
async def update_user_notes(
    user_id: str,
    body: AdminNotesRequest,
    admin: User = Depends(require_admin),
    svc: AdminUsersService = Depends(get_admin_users_service),
):
    """Met à jour les notes admin (texte libre) sur la fiche d'un user."""
    user = await svc.update_admin_notes(
        user_id, body.notes,
        admin_id=str(admin.id), caller_role=admin.role,
    )
    return {
        "id": str(user.id),
        "admin_notes": user.admin_notes,
        "message": "Notes updated",
    }


@router.patch("/users/{user_id}/role")
async def update_user_role(
    user_id: str,
    body: dict,
    admin: User = Depends(require_super_admin),
    svc: AdminUsersService = Depends(get_admin_users_service),
):
    """Promote ou demote un user, réservé au super_admin (hiérarchie standard)."""
    new_role = body.get("role")
    user = await svc.update_user_role(user_id, new_role, admin_id=str(admin.id))
    return {
        "id": str(user.id),
        "role": user.role,
        "message": f"Role updated to {user.role}",
    }


@router.delete("/users/{user_id}")
async def delete_user(
    user_id: str,
    admin: User = Depends(require_admin),
    svc: AdminUsersService = Depends(get_admin_users_service),
    r2: R2Service = Depends(get_r2_service),
    session: AsyncSession = Depends(get_db_session),
):
    await svc.delete_user(
        user_id,
        admin_id=str(admin.id),
        caller_role=admin.role,
        r2_service=r2,
        application_repo=ApplicationRepository(session),
        coach_repo=CoachRepository(session),
    )
    return {"message": "User deleted successfully"}


# Audit log

@router.get("/audit-log", response_model=AdminAuditLogResponse)
async def get_audit_log(
    page: int = Query(1, ge=1),
    limit: int = Query(100, ge=1, le=500),
    action: str | None = None,
    target_id: str | None = None,
    search: str | None = None,
    svc: AdminAuditService = Depends(get_admin_audit_service),
):
    result = await svc.get_audit_log(
        page=page, page_size=limit,
        action=action, target_id=target_id, search=search,
    )
    return {
        "entries": [
            {
                "id": str(e.id),
                "admin_user_id": str(e.admin_user_id) if e.admin_user_id else None,
                "action": e.action,
                "target_type": e.target_type,
                "target_id": e.target_id,
                "payload": e.payload,
                "created_at": e.created_at.isoformat() if e.created_at else "",
            }
            for e in result["entries"]
        ],
        "total": result["total"],
        "page": result["page"],
        "page_size": result["page_size"],
    }


# Sentry, proxy vers l'API Sentry pour la page Erreurs du panel admin

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
