"""Repository pour les sessions coach IA."""

from sqlalchemy import select, delete, update
from sqlalchemy.ext.asyncio import AsyncSession

from models.db_models import CoachSession, User


class CoachRepository:
    def __init__(self, session: AsyncSession):
        self.session = session

    async def create(self, data: dict) -> CoachSession:
        session = CoachSession(**data)
        self.session.add(session)
        await self.session.flush()
        await self.session.refresh(session)
        return session

    async def get_by_id(self, session_id: str, user_id: str) -> CoachSession | None:
        result = await self.session.execute(
            select(CoachSession).where(
                CoachSession.id == session_id,
                CoachSession.user_id == user_id,
            )
        )
        return result.scalar_one_or_none()
    
    # Retourne les sessions triées par date desc (sans le JSONB complet)
    async def get_all_by_user(self, user_id: str) -> list[CoachSession]:
        result = await self.session.execute(
            select(CoachSession)
            .where(CoachSession.user_id == user_id)
            .order_by(CoachSession.created_at.desc())
        )
        return list(result.scalars().all())
    
    # Supprime une session et retourne l'objet pour cleanup R2
    async def delete_session(self, session_id: str, user_id: str) -> CoachSession | None:
        session = await self.get_by_id(session_id, user_id)
        if not session:
            return None
        await self.session.delete(session)
        await self.session.flush()
        return session
    
    # Supprime toutes les sessions d'un utilisateur, retourne les cv_file_keys pour cleanup R2
    async def delete_all_by_user(self, user_id: str) -> list[str]:
        result = await self.session.execute(
            select(CoachSession.cv_file_key).where(
                CoachSession.user_id == user_id,
                CoachSession.cv_file_key.isnot(None),
            )
        )
        keys = [r[0] for r in result.all()]

        await self.session.execute(
            delete(CoachSession).where(CoachSession.user_id == user_id)
        )
        await self.session.flush()
        return keys

    # ─── Usage tracking ──────────────────────────────────────────

    async def get_usage(self, user_id: str) -> dict:
        result = await self.session.execute(
            select(User.coach_usage_count, User.coach_usage_reset_at).where(
                User.id == user_id
            )
        )
        row = result.one_or_none()
        if not row:
            return {"coach_usage_count": 0, "coach_usage_reset_at": None}
        return {
            "coach_usage_count": row[0] or 0,
            "coach_usage_reset_at": row[1],
        }

    async def increment_usage(self, user_id: str) -> None:
        await self.session.execute(
            update(User)
            .where(User.id == user_id)
            .values(coach_usage_count=User.coach_usage_count + 1)
        )
        await self.session.flush()

    async def reset_usage(self, user_id: str, reset_at) -> None:
        await self.session.execute(
            update(User)
            .where(User.id == user_id)
            .values(coach_usage_count=0, coach_usage_reset_at=reset_at)
        )
        await self.session.flush()
