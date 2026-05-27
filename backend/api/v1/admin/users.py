from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from api.v1.admin.dependencies import (
    get_admin_users_service,
    require_admin,
    require_super_admin,
)
from api.v1.client.dependencies import get_r2_service
from core.config import ADMIN_EMAIL
from core.database import get_db_session
from models.db_models import User
from services.admin.users_service import AdminUsersService
from models.api_schemas import (
    AdminStatusRequest,
    AdminUserActionResponse,
    AdminUserDetailResponse,
    AdminUserListResponse,
)
from models.api_schemas.admin import AdminEmailRequest, AdminNotesRequest
from repositories.application_repository import ApplicationRepository
from repositories.coach_repository import CoachRepository
from services.storage.r2_service import R2Service

router = APIRouter(tags=["admin"])


# Helpers de conversion (modèles SQLAlchemy vers dicts pour DTOs)

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

# Envoie un email texte brut à un user, réservé au super_admin
@router.post("/users/{user_id}/email")
async def send_email_to_user(
    user_id: str,
    body: AdminEmailRequest,
    admin: User = Depends(require_super_admin),
    svc: AdminUsersService = Depends(get_admin_users_service),
):
    await svc.send_email(
        user_id, body.subject, body.body,
        admin_id=str(admin.id), caller_role=admin.role,
    )
    return {"message": "Email sent"}

# Met à jour les notes admin (texte libre) sur la fiche d'un user
@router.patch("/users/{user_id}/notes")
async def update_user_notes(
    user_id: str,
    body: AdminNotesRequest,
    admin: User = Depends(require_admin),
    svc: AdminUsersService = Depends(get_admin_users_service),
):
    user = await svc.update_admin_notes(
        user_id, body.notes,
        admin_id=str(admin.id), caller_role=admin.role,
    )
    return {
        "id": str(user.id),
        "admin_notes": user.admin_notes,
        "message": "Notes updated",
    }

# # Promote ou demote un user, réservé au super_admin (hiérarchie standard)
@router.patch("/users/{user_id}/role")
async def update_user_role(
    user_id: str,
    body: dict,
    admin: User = Depends(require_super_admin),
    svc: AdminUsersService = Depends(get_admin_users_service),
):
    new_role = body.get("role")
    user = await svc.update_user_role(user_id, new_role, admin_id=str(admin.id))
    return {
        "id": str(user.id),
        "role": user.role,
        "message": f"Role updated to {user.role}",
    }

# Supprime un user et toutes ses données associées, réservé au super_admin (action irréversible)
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
