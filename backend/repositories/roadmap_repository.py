from sqlalchemy import select, update, delete
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from models.db_models import Roadmap, RoadmapPhase, Career


class RoadmapRepository:
    def __init__(self, session: AsyncSession):
        self.session = session

    # Roadmap CRUD 

    async def create_roadmap(self, user_id: str, summary: dict | None = None) -> Roadmap:
        roadmap = Roadmap(user_id=user_id, summary=summary, status="active")
        self.session.add(roadmap)
        await self.session.flush()
        return roadmap

    async def create_phases(self, roadmap_id, phases_list: list[dict]) -> list[RoadmapPhase]:
        phases = []
        for p in phases_list:
            p["roadmap_id"] = roadmap_id
            phase = RoadmapPhase(**p)
            phases.append(phase)
        self.session.add_all(phases)
        await self.session.flush()
        return phases

    async def get_active_roadmap(self, user_id: str) -> Roadmap | None:
        result = await self.session.execute(
            select(Roadmap)
            .options(selectinload(Roadmap.phases))
            .where(Roadmap.user_id == user_id, Roadmap.status == "active")
        )
        return result.scalar_one_or_none()

    async def get_by_id(self, roadmap_id: str, user_id: str) -> Roadmap | None:
        result = await self.session.execute(
            select(Roadmap)
            .options(selectinload(Roadmap.phases))
            .where(Roadmap.id == roadmap_id, Roadmap.user_id == user_id)
        )
        return result.scalar_one_or_none()

    async def archive_active(self, user_id: str) -> None:
        await self.session.execute(
            update(Roadmap)
            .where(Roadmap.user_id == user_id, Roadmap.status == "active")
            .values(status="archived")
        )
        await self.session.flush()

    async def get_history(self, user_id: str) -> list[Roadmap]:
        result = await self.session.execute(
            select(Roadmap)
            .options(selectinload(Roadmap.phases))
            .where(Roadmap.user_id == user_id, Roadmap.status == "archived")
            .order_by(Roadmap.created_at.desc())
        )
        return list(result.scalars().all())

    async def restore(self, roadmap_id: str, user_id: str) -> Roadmap | None:
        roadmap = await self.get_by_id(roadmap_id, user_id)
        if not roadmap or roadmap.status != "archived":
            return None
        await self.archive_active(user_id)
        roadmap.status = "active"
        await self.session.flush()
        return roadmap

    #  Phase operations 

    async def get_phase(self, phase_id: str, user_id: str) -> RoadmapPhase | None:
        result = await self.session.execute(
            select(RoadmapPhase)
            .join(Roadmap)
            .where(RoadmapPhase.id == phase_id, Roadmap.user_id == user_id)
        )
        return result.scalar_one_or_none()

    async def update_phase(self, phase_id: str, data: dict) -> RoadmapPhase | None:
        result = await self.session.execute(
            select(RoadmapPhase).where(RoadmapPhase.id == phase_id)
        )
        phase = result.scalar_one_or_none()
        if not phase:
            return None
        for key, value in data.items():
            setattr(phase, key, value)
        await self.session.flush()
        return phase

    async def toggle_phase_complete(self, phase_id: str) -> RoadmapPhase | None:
        result = await self.session.execute(
            select(RoadmapPhase).where(RoadmapPhase.id == phase_id)
        )
        phase = result.scalar_one_or_none()
        if not phase:
            return None
        phase.completed = not phase.completed
        await self.session.flush()
        return phase

    async def add_phase(self, roadmap_id, phase_data: dict, position: int) -> RoadmapPhase:
        # Shift positions of phases at or after the insert position
        await self.session.execute(
            update(RoadmapPhase)
            .where(RoadmapPhase.roadmap_id == roadmap_id, RoadmapPhase.position >= position)
            .values(position=RoadmapPhase.position + 1, phase_number=RoadmapPhase.phase_number + 1)
        )
        phase_data["roadmap_id"] = roadmap_id
        phase_data["position"] = position
        phase_data["custom"] = True
        phase = RoadmapPhase(**phase_data)
        self.session.add(phase)
        await self.session.flush()
        return phase

    async def delete_phase(self, phase_id: str) -> None:
        result = await self.session.execute(
            select(RoadmapPhase).where(RoadmapPhase.id == phase_id)
        )
        phase = result.scalar_one_or_none()
        if not phase:
            return
        roadmap_id = phase.roadmap_id
        position = phase.position
        await self.session.delete(phase)
        await self.session.flush()
        # Shift positions down for phases after the deleted one
        await self.session.execute(
            update(RoadmapPhase)
            .where(RoadmapPhase.roadmap_id == roadmap_id, RoadmapPhase.position > position)
            .values(position=RoadmapPhase.position - 1, phase_number=RoadmapPhase.phase_number - 1)
        )
        await self.session.flush()

    async def reorder_phases(self, roadmap_id, phase_ids_ordered: list[str]) -> None:
        for i, phase_id in enumerate(phase_ids_ordered):
            await self.session.execute(
                update(RoadmapPhase)
                .where(RoadmapPhase.id == phase_id, RoadmapPhase.roadmap_id == roadmap_id)
                .values(position=i, phase_number=i + 1)
            )
        await self.session.flush()

    # Suppression de roadmaps
    # Supprime une roadmap et ses phases (cascade)
    async def delete_roadmap(self, roadmap_id: str, user_id: str) -> bool:
        roadmap = await self.get_by_id(roadmap_id, user_id)
        if not roadmap:
            return False
        # Supprimer les phases d'abord
        await self.session.execute(
            delete(RoadmapPhase).where(RoadmapPhase.roadmap_id == roadmap_id)
        )
        await self.session.delete(roadmap)
        await self.session.flush()
        return True
    
    # Supprime toutes les roadmaps archivées d'un utilisateur
    async def delete_all_archived(self, user_id: str) -> int:
        # Récupérer les IDs des roadmaps archivées
        result = await self.session.execute(
            select(Roadmap.id).where(
                Roadmap.user_id == user_id, Roadmap.status == "archived"
            )
        )
        ids = [r[0] for r in result.all()]
        if not ids:
            return 0
        # Supprimer les phases puis les roadmaps
        await self.session.execute(
            delete(RoadmapPhase).where(RoadmapPhase.roadmap_id.in_(ids))
        )
        await self.session.execute(
            delete(Roadmap).where(Roadmap.id.in_(ids))
        )
        await self.session.flush()
        return len(ids)

    # Career generation status

    async def set_generation_status(self, user_id: str, status: str) -> None:
        await self.session.execute(
            update(Career).where(Career.user_id == user_id).values(generation_status=status)
        )
        await self.session.flush()
