"""Repository pour les endpoints /v1/admin/* — accès cross-domain (users + stats agrégées)."""

from datetime import datetime, timedelta, timezone

from sqlalchemy import desc, func, or_, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from models.db import (
    Application,
    Career,
    CoachSession,
    InterviewSession,
    Roadmap,
    RoadmapPhase,
    User,
)


# Coûts estimés par appel IA (USD) — basés sur les modèles utilisés et les tailles de prompts moyennes
_COST_PER_ROADMAP = 0.15           # gpt-4o avec ~10k tokens cumulés
_COST_PER_COACH_SESSION = 0.005    # gpt-4o-mini avec ~3-5k tokens
_COST_PER_INTERVIEW_SESSION = 0.01  # gpt-4o-mini multi-tours avec ~10-20k tokens cumulés


class AdminRepository:
    def __init__(self, session: AsyncSession):
        self.session = session

    # Users CRUD admin

    async def list_users(
        self,
        *,
        offset: int = 0,
        limit: int = 50,
        role: str | None = None,
        is_active: bool | None = None,
        verified: bool | None = None,
        search: str | None = None,
    ) -> tuple[list[User], int]:
        query = select(User)
        count_query = select(func.count()).select_from(User)

        conditions = []
        if role is not None:
            conditions.append(User.role == role)
        if is_active is not None:
            conditions.append(User.is_active == is_active)
        if verified is not None:
            conditions.append(User.is_verified == verified)
        if search:
            pattern = f"%{search}%"
            conditions.append(
                or_(User.email.ilike(pattern), User.first_name.ilike(pattern), User.last_name.ilike(pattern))
            )

        for cond in conditions:
            query = query.where(cond)
            count_query = count_query.where(cond)

        query = query.order_by(desc(User.created_at)).offset(offset).limit(limit)

        rows_result = await self.session.execute(query)
        count_result = await self.session.execute(count_query)
        return list(rows_result.scalars().all()), int(count_result.scalar() or 0)

    async def get_user(self, user_id: str) -> User | None:
        result = await self.session.execute(select(User).where(User.id == user_id))
        return result.scalar_one_or_none()

    async def update_user_role(self, user_id: str, role: str) -> User | None:
        await self.session.execute(
            update(User).where(User.id == user_id).values(role=role)
        )
        await self.session.flush()
        return await self.get_user(user_id)

    async def set_user_status(self, user_id: str, is_active: bool, reason: str | None = None) -> User | None:
        # Active ou désactive un compte — quand on désactive, garde la trace (timestamp + reason)
        values: dict = {"is_active": is_active}
        if is_active:
            values["deactivated_at"] = None
            values["deactivation_reason"] = None
        else:
            values["deactivated_at"] = datetime.now(timezone.utc)
            values["deactivation_reason"] = reason

        await self.session.execute(
            update(User).where(User.id == user_id).values(**values)
        )
        await self.session.flush()
        return await self.get_user(user_id)

    async def reset_user_limits(self, user_id: str) -> None:
        # Reset les compteurs d'usage IA — utile en support si un user a un problème
        await self.session.execute(
            update(User).where(User.id == user_id).values(
                coach_usage_count=0,
                interview_usage_count=0,
            )
        )
        # regeneration_count est sur la table Career (pas User)
        await self.session.execute(
            update(Career).where(Career.user_id == user_id).values(regeneration_count=0)
        )
        await self.session.flush()

    # Détail user

    async def get_user_stats(self, user_id: str) -> dict:
        apps = await self.session.execute(
            select(func.count()).select_from(Application).where(Application.user_id == user_id)
        )
        roadmaps = await self.session.execute(
            select(func.count()).select_from(Roadmap).where(Roadmap.user_id == user_id)
        )
        coach = await self.session.execute(
            select(func.count()).select_from(CoachSession).where(CoachSession.user_id == user_id)
        )
        interview = await self.session.execute(
            select(func.count()).select_from(InterviewSession).where(InterviewSession.user_id == user_id)
        )
        return {
            "applications": int(apps.scalar() or 0),
            "roadmaps": int(roadmaps.scalar() or 0),
            "coach_sessions": int(coach.scalar() or 0),
            "interview_sessions": int(interview.scalar() or 0),
        }

    # Stats globales (dashboard)

    async def count_users(
        self,
        *,
        role: str | None = None,
        is_active: bool | None = None,
        verified: bool | None = None,
    ) -> int:
        query = select(func.count()).select_from(User)
        if role is not None:
            query = query.where(User.role == role)
        if is_active is not None:
            query = query.where(User.is_active == is_active)
        if verified is not None:
            query = query.where(User.is_verified == verified)
        result = await self.session.execute(query)
        return int(result.scalar() or 0)

    async def count_active_users_since(self, since: datetime) -> int:
        # Compte les users dont l'updated_at est postérieur à `since` (approximation de "actifs")
        result = await self.session.execute(
            select(func.count()).select_from(User).where(User.updated_at >= since)
        )
        return int(result.scalar() or 0)

    async def count_signups_grouped_by_day(self, since: datetime) -> list[dict]:
        # Inscriptions par jour depuis `since` (pour le graphique)
        result = await self.session.execute(
            select(
                func.date(User.created_at).label("date"),
                func.count().label("count"),
            )
            .where(User.created_at >= since)
            .group_by(func.date(User.created_at))
            .order_by(func.date(User.created_at))
        )
        return [{"date": str(row.date), "count": int(row.count)} for row in result.all()]

    # Roadmaps

    async def count_roadmaps(self) -> int:
        result = await self.session.execute(select(func.count()).select_from(Roadmap))
        return int(result.scalar() or 0)

    async def count_manual_roadmaps(self) -> int:
        # Roadmap manuelle = TOUTES ses phases ont custom=true
        # On compte les roadmaps qui n'ont AUCUNE phase non-custom
        subquery_has_ai_phase = (
            select(RoadmapPhase.roadmap_id)
            .where(RoadmapPhase.custom == False)  # noqa: E712
            .subquery()
        )
        result = await self.session.execute(
            select(func.count()).select_from(Roadmap).where(
                Roadmap.id.notin_(select(subquery_has_ai_phase.c.roadmap_id))
            )
        )
        return int(result.scalar() or 0)

    async def count_ai_roadmaps(self) -> int:
        # Roadmap IA = au moins une phase non-custom (générée par GPT)
        total = await self.count_roadmaps()
        manual = await self.count_manual_roadmaps()
        return total - manual

    # Coach / Interview

    async def count_applications(self) -> int:
        result = await self.session.execute(select(func.count()).select_from(Application))
        return int(result.scalar() or 0)

    async def count_coach_sessions_since(self, since: datetime) -> int:
        result = await self.session.execute(
            select(func.count()).select_from(CoachSession).where(CoachSession.created_at >= since)
        )
        return int(result.scalar() or 0)

    async def count_interview_sessions_since(self, since: datetime) -> int:
        result = await self.session.execute(
            select(func.count()).select_from(InterviewSession).where(InterviewSession.created_at >= since)
        )
        return int(result.scalar() or 0)

    async def count_coach_sessions(self) -> int:
        result = await self.session.execute(select(func.count()).select_from(CoachSession))
        return int(result.scalar() or 0)

    async def count_interview_sessions(self) -> int:
        result = await self.session.execute(select(func.count()).select_from(InterviewSession))
        return int(result.scalar() or 0)

    async def estimate_openai_cost(self) -> float:
        # Estimation à la louche du coût OpenAI cumulé (USD) — pas de tracking précis des tokens
        roadmaps = await self.count_roadmaps()
        coach = await self.count_coach_sessions()
        interview = await self.count_interview_sessions()
        total = (
            roadmaps * _COST_PER_ROADMAP
            + coach * _COST_PER_COACH_SESSION
            + interview * _COST_PER_INTERVIEW_SESSION
        )
        return round(total, 2)
