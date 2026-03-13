import copy

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

    # Récupère un roadmap par id + user_id (sécurité)
    async def get_by_id(self, roadmap_id: str, user_id: str) -> Roadmap | None:
        result = await self.session.execute(
            select(Roadmap).where(Roadmap.id == roadmap_id, Roadmap.user_id == user_id)
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

    # Restaure un roadmap archivé → le rend actif
    async def restore(self, roadmap_id: str, user_id: str) -> Roadmap | None:
        roadmap = await self.get_by_id(roadmap_id, user_id)
        if not roadmap or roadmap.status != "archived":
            return None
        # Archiver le roadmap actif actuel
        await self.archive_active(user_id)
        # Réactiver l'ancien
        roadmap.status = "active"
        await self.session.flush()
        return roadmap

    # Met à jour le generation_status sur career
    async def set_generation_status(self, user_id: str, status: str) -> None:
        await self.session.execute(
            update(Career).where(Career.user_id == user_id).values(generation_status=status)
        )
        await self.session.flush()

    # ─── Méthodes de modification des phases ─────────────────────────

    # Remplace le JSONB phases complet
    async def update_phases(self, roadmap_id: str, user_id: str, phases: list[dict]) -> Roadmap | None:
        roadmap = await self.get_by_id(roadmap_id, user_id)
        if not roadmap:
            return None
        roadmap.phases = phases
        await self.session.flush()
        return roadmap

    # Ajoute une phase custom à la position souhaitée
    async def add_phase(self, roadmap_id: str, user_id: str, phase: dict, position: int | None) -> Roadmap | None:
        roadmap = await self.get_by_id(roadmap_id, user_id)
        if not roadmap:
            return None

        phases = copy.deepcopy(roadmap.phases) if roadmap.phases else []
        phase["custom"] = True
        phase["completed"] = False

        if position is not None and 0 <= position <= len(phases):
            phases.insert(position, phase)
        else:
            phases.append(phase)

        # Renumérotation des phase_number
        for i, p in enumerate(phases):
            p["phase_number"] = i + 1

        roadmap.phases = phases
        await self.session.flush()
        return roadmap

    # Supprime une phase par numéro
    async def delete_phase(self, roadmap_id: str, user_id: str, phase_number: int) -> Roadmap | None:
        roadmap = await self.get_by_id(roadmap_id, user_id)
        if not roadmap:
            return None

        phases = copy.deepcopy(roadmap.phases) if roadmap.phases else []
        original_len = len(phases)
        phases = [p for p in phases if p.get("phase_number") != phase_number]

        if len(phases) == original_len:
            return None  # Phase non trouvée

        # Renumérotation
        for i, p in enumerate(phases):
            p["phase_number"] = i + 1

        roadmap.phases = phases
        await self.session.flush()
        return roadmap

    # Toggle completed sur une phase
    async def toggle_phase_complete(self, roadmap_id: str, user_id: str, phase_number: int) -> Roadmap | None:
        roadmap = await self.get_by_id(roadmap_id, user_id)
        if not roadmap:
            return None

        phases = copy.deepcopy(roadmap.phases) if roadmap.phases else []
        found = False
        for p in phases:
            if p.get("phase_number") == phase_number:
                p["completed"] = not p.get("completed", False)
                found = True
                break

        if not found:
            return None

        roadmap.phases = phases
        await self.session.flush()
        return roadmap

    # Toggle completed sur une action
    async def toggle_action_complete(
        self, roadmap_id: str, user_id: str, phase_number: int, action_index: int
    ) -> Roadmap | None:
        roadmap = await self.get_by_id(roadmap_id, user_id)
        if not roadmap:
            return None

        phases = copy.deepcopy(roadmap.phases) if roadmap.phases else []
        found = False
        for p in phases:
            if p.get("phase_number") == phase_number:
                actions = p.get("actions", [])
                if 0 <= action_index < len(actions):
                    actions[action_index]["completed"] = not actions[action_index].get("completed", False)
                    found = True
                break

        if not found:
            return None

        roadmap.phases = phases
        await self.session.flush()
        return roadmap
