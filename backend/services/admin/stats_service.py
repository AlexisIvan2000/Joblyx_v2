from datetime import datetime, timedelta, timezone

from sqlalchemy.ext.asyncio import AsyncSession

from repositories.admin_repository import AdminRepository


class AdminStatsService:
    def __init__(self, session: AsyncSession):
        self.session = session
        self.admin_repo = AdminRepository(session)

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
            # Coût OpenAI réel (tokens trackés), pas une estimation
            "openai_cost_total_usd": await self.admin_repo.get_openai_cost_total(),
            "openai_cost_month_usd": await self.admin_repo.get_openai_cost_since(start_of_month),
            "openai_cost_by_feature": await self.admin_repo.get_openai_cost_by_feature(start_of_month),
        }

    async def get_registrations(self, period: str = "week") -> list[dict]:
        # Inscriptions groupées par jour pour la période demandée (week = 7j, month = 30j)
        now = datetime.now(timezone.utc)
        if period == "month":
            since = now - timedelta(days=30)
        else:
            since = now - timedelta(days=7)
        return await self.admin_repo.count_signups_grouped_by_day(since)
