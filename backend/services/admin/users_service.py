import logging

from sqlalchemy.ext.asyncio import AsyncSession

from core.exceptions import UserNotFound, ValidationError
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

_ALLOWED_ROLES = ("user", "admin", "super_admin")


class AdminUsersService:
    def __init__(self, session: AsyncSession):
        self.session = session
        self.admin_repo = AdminRepository(session)
        self.audit_repo = AuditLogRepository(session)
        self.auth_repo = AuthRepository(session)
        self.rt_repo = RefreshTokenRepository(session)

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

        # Une query stats par user (acceptable jusqu'à ~50 users par page)
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

        return {
            "user": user,
            "career": await career_repo.get_by_user_id(user_id),
            "skills": await career_repo.get_skills(user_id),
            "active_roadmap": await roadmap_repo.get_active_roadmap(user_id),
            "applications": await app_repo.get_all_by_user(user_id),
            "coach_sessions": await coach_repo.get_all_by_user(user_id),
            "interview_sessions": await interview_repo.get_sessions_by_user(user_id),
        }

    async def set_user_status(
        self, user_id: str, is_active: bool, reason: str | None = None,
        *, admin_id: str | None = None,
    ):
        target = await self.admin_repo.get_user(user_id)
        if not target:
            raise UserNotFound()

        updated_user = await self.admin_repo.set_user_status(user_id, is_active, reason)

        # Quand on désactive, révoque tous les refresh tokens pour empêcher la reconnexion
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

    async def update_user_role(
        self, user_id: str, new_role: str,
        *, admin_id: str | None = None,
    ):
        if new_role not in _ALLOWED_ROLES:
            raise ValidationError(f"Invalid role: {new_role}")

        target = await self.admin_repo.get_user(user_id)
        if not target:
            raise UserNotFound()

        # Empêche un super_admin de se rétrograder lui-même par accident
        if admin_id and str(target.id) == admin_id:
            raise ValidationError("You cannot change your own role")

        previous_role = target.role
        updated_user = await self.admin_repo.update_user_role(user_id, new_role)

        await self.audit_repo.create(
            admin_id=admin_id,
            action="user.role.change",
            target_type="user",
            target_id=user_id,
            payload={
                "target_email": target.email,
                "previous_role": previous_role,
                "new_role": new_role,
            },
        )
        await self.session.commit()
        logger.info(
            "Admin role change: admin=%s target=%s previous=%s new=%s",
            admin_id, user_id, previous_role, new_role,
        )
        return updated_user

    async def update_admin_notes(
        self, user_id: str, notes: str | None,
        *, admin_id: str | None = None,
    ):
        target = await self.admin_repo.get_user(user_id)
        if not target:
            raise UserNotFound()

        # Normalise les notes vides en None pour rester cohérent
        cleaned = notes.strip() if notes else None
        if cleaned == "":
            cleaned = None

        previous_had_notes = bool(target.admin_notes)
        updated_user = await self.admin_repo.update_admin_notes(user_id, cleaned)

        await self.audit_repo.create(
            admin_id=admin_id,
            action="user.notes.update",
            target_type="user",
            target_id=user_id,
            payload={
                "target_email": target.email,
                "previous_had_notes": previous_had_notes,
                "new_length": len(cleaned) if cleaned else 0,
            },
        )
        await self.session.commit()
        logger.info(
            "Admin notes update: admin=%s target=%s length=%d",
            admin_id, user_id, len(cleaned) if cleaned else 0,
        )
        return updated_user

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

        # Audit log AVANT la suppression, on capture l'email pour l'historique
        await self.audit_repo.create(
            admin_id=admin_id,
            action="user.delete",
            target_type="user",
            target_id=user_id,
            payload={"target_email": target.email, "target_role": target.role},
        )

        # Supprime le user, le CASCADE FK supprime toutes les données liées
        await self.auth_repo.delete_user(user_id)
        await self.session.commit()
        logger.info("Admin delete: admin=%s target=%s email=%s", admin_id, user_id, target.email)

        # Cleanup R2 best-effort, un échec laisse les fichiers orphelins mais ne casse pas la suppression
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
