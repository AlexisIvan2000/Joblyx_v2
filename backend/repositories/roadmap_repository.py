from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from models.db_models import Roadmap, Career


class RoadmapRepository:
    def __init__(self, session: AsyncSession):
        self.session = session

    # Crée un nouveau roadmap avec status 'active'
    async def create(self, user_id: str, target_jobs: list[str], market_data: dict | None, phases: dict) -> Roadmap:
        roadmap = Roadmap(
            user_id=user_id,
            target_jobs=target_jobs,
            market_data=market_data,
            phases=phases,
            status="active",
        )
        self.session.add(roadmap)
        await self.session.flush()
        return roadmap

    # Récupère le roadmap actif d'un utilisateur
    async def get_active_by_user_id(self, user_id: str) -> Roadmap | None:
        result = await self.session.execute(
            select(Roadmap).where(Roadmap.user_id == user_id, Roadmap.status == "active")
        )
        return result.scalar_one_or_none()

    # Archive le roadmap actif (status → 'archived')
    async def archive_active(self, user_id: str) -> None:
        await self.session.execute(
            update(Roadmap)
            .where(Roadmap.user_id == user_id, Roadmap.status == "active")
            .values(status="archived")
        )
        await self.session.flush()

    # Retourne l'historique des roadmaps archivés
    async def get_history_by_user_id(self, user_id: str) -> list[Roadmap]:
        result = await self.session.execute(
            select(Roadmap)
            .where(Roadmap.user_id == user_id, Roadmap.status == "archived")
            .order_by(Roadmap.created_at.desc())
        )
        return list(result.scalars().all())

    # Met à jour le generation_status sur career
    async def set_generation_status(self, user_id: str, status: str) -> None:
        await self.session.execute(
            update(Career).where(Career.user_id == user_id).values(generation_status=status)
        )
        await self.session.flush()
