import copy
import logging

from sqlalchemy.ext.asyncio import AsyncSession

from core.exceptions import (
    ActionNotFound,
    InvalidPhaseIdsForReorder,
    NoActiveRoadmap,
    PhaseNotFound,
    SkillIndexNotFound,
)
from repositories.roadmap_repository import RoadmapRepository

logger = logging.getLogger(__name__)


class RoadmapPhaseService:
    def __init__(self, session: AsyncSession):
        self.session = session
        self.repo = RoadmapRepository(session)

    async def add_phase(self, user_id: str, body):
        roadmap = await self.repo.get_active_roadmap(user_id)
        if not roadmap:
            raise NoActiveRoadmap()

        position = body.position if body.position is not None else len(roadmap.phases)
        phase_data = body.model_dump(exclude={"position"})
        phase_data["phase_number"] = position + 1

        phase = await self.repo.add_phase(roadmap.id, phase_data, position)
        await self.session.commit()
        return phase

    async def update_phase(self, phase_id: str, user_id: str, data: dict):
        phase = await self.repo.get_phase(phase_id, user_id)
        if not phase:
            raise PhaseNotFound()

        clean_data = {k: v for k, v in data.items() if v is not None}
        if not clean_data:
            return phase

        phase = await self.repo.update_phase(phase_id, clean_data)
        await self.session.commit()
        return phase

    async def delete_phase(self, phase_id: str, user_id: str) -> None:
        phase = await self.repo.get_phase(phase_id, user_id)
        if not phase:
            raise PhaseNotFound()
        await self.repo.delete_phase(phase_id)
        await self.session.commit()

    async def toggle_phase_complete(self, phase_id: str, user_id: str):
        phase = await self.repo.get_phase(phase_id, user_id)
        if not phase:
            raise PhaseNotFound()
        phase = await self.repo.toggle_phase_complete(phase_id)
        await self.session.commit()
        return phase

    async def toggle_action_complete(self, phase_id: str, user_id: str, action_index: int):
        phase = await self.repo.get_phase(phase_id, user_id)
        if not phase:
            raise PhaseNotFound()

        actions = copy.deepcopy(phase.actions or [])
        if action_index < 0 or action_index >= len(actions):
            raise ActionNotFound()

        actions[action_index]["completed"] = not actions[action_index].get("completed", False)
        phase = await self.repo.update_phase(phase_id, {"actions": actions})
        await self.session.commit()
        return phase

    async def toggle_skill_complete(self, phase_id: str, user_id: str, skill_index: int):
        phase = await self.repo.get_phase(phase_id, user_id)
        if not phase:
            raise PhaseNotFound()

        skills = copy.deepcopy(phase.skills or [])
        if skill_index < 0 or skill_index >= len(skills):
            raise SkillIndexNotFound()

        skills[skill_index]["completed"] = not skills[skill_index].get("completed", False)
        phase = await self.repo.update_phase(phase_id, {"skills": skills})
        await self.session.commit()
        return phase

    async def reorder_phases(self, user_id: str, phase_ids: list[str]) -> None:
        roadmap = await self.repo.get_active_roadmap(user_id)
        if not roadmap:
            raise NoActiveRoadmap()

        roadmap_phase_ids = {str(p.id) for p in roadmap.phases}
        if set(phase_ids) != roadmap_phase_ids:
            raise InvalidPhaseIdsForReorder()

        await self.repo.reorder_phases(roadmap.id, phase_ids)
        await self.session.commit()
