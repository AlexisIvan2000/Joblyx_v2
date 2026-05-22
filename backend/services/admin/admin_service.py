import logging
from datetime import datetime, timedelta, timezone

from sqlalchemy.ext.asyncio import AsyncSession

from core.exceptions import UserNotFound
from repositories.admin_repository import AdminRepository
from repositories.application_repository import ApplicationRepository
from repositories.audit_log_repository import AuditLogRepository
from repositories.auth_repository import AuthRepository
from repositories.career_repository import CareerRepository
from repositories.coach_repository import CoachRepository
from repositories.interview_repository import InterviewRepository
from repositories.refresh_token_repository import RefreshTokenRepository
from repositories.roadmap_repository import RoadmapRepository

logger = logging.getLogger(__name__)


class AdminService:
    def __init__(self, session: AsyncSession):
        self.session = session
        self.admin_repo = AdminRepository(session)
        self.audit_repo = AuditLogRepository(session)
        self.auth_repo = AuthRepository(session)
        self.rt_repo = RefreshTokenRepository(session)

    # Listing & détail

    async def list_users(
        self,
        *,
        page: int = 1,
        page_size: int = 20,
        search: str | None = None,
        is_active: bool | None = None,
        verified: bool | None = None,
        role: str | None = None,
    ) -> dict:
        offset = (page - 1) * page_size
        users, total = await self.admin_repo.list_users(
            offset=offset, limit=page_size,
            role=role, is_active=is_active, verified=verified, search=search,
        )

        # Pour chaque user, on récupère ses counts (1 query par user — acceptable jusqu'à ~50 users/page)
        users_with_stats = []
        for u in users:
            stats = await self.admin_repo.get_user_stats(str(u.id))
            users_with_stats.append({"user": u, "stats": stats})

        return {
            "users": users_with_stats,
            "total": total,
            "page": page,
            "page_size": page_size,
        }

    async def get_user_detail(self, user_id: str) -> dict:
        # Récupère tout le contexte d'un user pour la page détail admin
        user = await self.admin_repo.get_user(user_id)
        if not user:
            raise UserNotFound()

        career_repo = CareerRepository(self.session)
        roadmap_repo = RoadmapRepository(self.session)
        app_repo = ApplicationRepository(self.session)
        coach_repo = CoachRepository(self.session)
        interview_repo = InterviewRepository(self.session)

        career = await career_repo.get_by_user_id(user_id)
        skills = await career_repo.get_skills(user_id)
        active_roadmap = await roadmap_repo.get_active_roadmap(user_id)
        applications = await app_repo.get_all_by_user(user_id)
        coach_sessions = await coach_repo.get_all_by_user(user_id)
        interview_sessions = await interview_repo.get_sessions_by_user(user_id)

        return {
            "user": user,
            "career": career,
            "skills": skills,
            "active_roadmap": active_roadmap,
            "applications": applications,
            "coach_sessions": coach_sessions,
            "interview_sessions": interview_sessions,
        }

    # Toggle statut (activate / deactivate)

    async def set_user_status(
        self, user_id: str, is_active: bool, reason: str | None = None,
        *, admin_id: str | None = None,
    ):
        target = await self.admin_repo.get_user(user_id)
        if not target:
            raise UserNotFound()

        updated_user = await self.admin_repo.set_user_status(user_id, is_active, reason)

        # Quand on désactive : révoque tous les refresh tokens pour empêcher la reconnexion
        if not is_active:
            await self.rt_repo.revoke_all_for_user(user_id)

        action = "user.deactivate" if not is_active else "user.activate"
        payload = {"target_email": target.email}
        if reason:
            payload["reason"] = reason
        await self.audit_repo.create(
            admin_id=admin_id,
            action=action,
            target_type="user",
            target_id=user_id,
            payload=payload,
        )
        await self.session.commit()
        logger.info("Admin set_status: admin=%s target=%s is_active=%s reason=%s", admin_id, user_id, is_active, reason)
        return updated_user

    # Reset des limites IA (support)

    async def reset_user_limits(self, user_id: str, *, admin_id: str | None = None):
        target = await self.admin_repo.get_user(user_id)
        if not target:
            raise UserNotFound()

        await self.admin_repo.reset_user_limits(user_id)

        await self.audit_repo.create(
            admin_id=admin_id,
            action="user.reset_limits",
            target_type="user",
            target_id=user_id,
            payload={"target_email": target.email},
        )
        await self.session.commit()
        logger.info("Admin reset_limits: admin=%s target=%s email=%s", admin_id, user_id, target.email)
        return target

    # Suppression (cleanup R2 inclus)

    async def delete_user(
        self,
        user_id: str,
        *,
        admin_id: str | None = None,
        r2_service=None,
        application_repo=None,
        coach_repo=None,
    ):
        target = await self.admin_repo.get_user(user_id)
        if not target:
            raise UserNotFound()

        # Collecte les file_keys AVANT le CASCADE (sinon les rows sont déjà supprimées)
        cv_keys: list[str] = []
        avatar_key: str | None = None

        if r2_service is not None:
            if application_repo is not None:
                cv_keys.extend(await application_repo.get_cv_keys_for_user(user_id))
            if coach_repo is not None:
                cv_keys.extend(await coach_repo.get_cv_keys_for_user(user_id))
            if target.avatar_url and not target.avatar_url.startswith("http"):
                avatar_key = target.avatar_url

        # Audit log AVANT la suppression — on capture l'email pour l'historique
        await self.audit_repo.create(
            admin_id=admin_id,
            action="user.delete",
            target_type="user",
            target_id=user_id,
            payload={"target_email": target.email, "target_role": target.role},
        )

        # Supprime le user — CASCADE supprime toutes les données liées
        await self.auth_repo.delete_user(user_id)
        await self.session.commit()
        logger.info("Admin delete: admin=%s target=%s email=%s", admin_id, user_id, target.email)

        # Cleanup R2 best-effort
        if r2_service is not None:
            for key in cv_keys:
                try:
                    await r2_service.delete_cv(key)
                except Exception:
                    logger.warning("Failed to delete CV from R2: key=%s", key)
            if avatar_key:
                try:
                    await r2_service.delete_avatar(avatar_key)
                except Exception:
                    logger.warning("Failed to delete avatar from R2: key=%s", avatar_key)

    # Dashboard stats — version finale selon la spec

    async def get_dashboard_stats(self) -> dict:
        now = datetime.now(timezone.utc)
        seven_days_ago = now - timedelta(days=7)
        start_of_month = datetime(now.year, now.month, 1, tzinfo=timezone.utc)

        return {
            "total_users": await self.admin_repo.count_users(),
            "verified_users": await self.admin_repo.count_users(verified=True),
            "active_users_week": await self.admin_repo.count_active_users_since(seven_days_ago),
            "total_roadmaps": await self.admin_repo.count_roadmaps(),
            "ai_roadmaps": await self.admin_repo.count_ai_roadmaps(),
            "manual_roadmaps": await self.admin_repo.count_manual_roadmaps(),
            "coach_sessions_month": await self.admin_repo.count_coach_sessions_since(start_of_month),
            "interview_sessions_month": await self.admin_repo.count_interview_sessions_since(start_of_month),
            "total_applications": await self.admin_repo.count_applications(),
            "openai_usage_estimate_usd": await self.admin_repo.estimate_openai_cost(),
        }

    async def get_registrations(self, period: str = "week") -> list[dict]:
        # Retourne les inscriptions groupées par jour pour la période demandée
        now = datetime.now(timezone.utc)
        if period == "month":
            since = now - timedelta(days=30)
        else:
            since = now - timedelta(days=7)
        return await self.admin_repo.count_signups_grouped_by_day(since)

    # Audit log

    async def get_audit_log(
        self,
        *,
        page: int = 1,
        page_size: int = 100,
        action: str | None = None,
        target_id: str | None = None,
    ) -> dict:
        offset = (page - 1) * page_size
        entries, total = await self.audit_repo.list_recent(
            offset=offset, limit=page_size,
            action=action, target_id=target_id,
        )
        return {"entries": entries, "total": total, "page": page, "page_size": page_size}
