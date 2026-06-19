import json
import logging

from sqlalchemy.ext.asyncio import AsyncSession

from core.exceptions import (
    NoActiveRoadmap,
    NoArchivedRoadmap,
    RoadmapNotFound,
)
from repositories.roadmap_repository import RoadmapRepository
from services.roadmap.career_service import CareerProfileService, career_to_dict
from services.roadmap.phase_service import RoadmapPhaseService
from services.roadmap.prompt_builder import build_roadmap_prompt
from services.ai.openai_client import generate_roadmap as call_gpt, generate_roadmap_stream

logger = logging.getLogger(__name__)


class RoadmapService:
    def __init__(self, session: AsyncSession):
        self.session = session
        self.repo = RoadmapRepository(session)
        self.career = CareerProfileService(session)
        self.phases = RoadmapPhaseService(session)

    async def get_career_profile(self, user_id: str) -> dict:
        return await self.career.get_career_profile(user_id)

    async def update_career_profile(self, user_id: str, body) -> dict:
        return await self.career.update_career_profile(user_id, body)

    async def save_career_and_skills(self, user_id: str, career_data: dict, skills_data: list[dict]) -> bool:
        return await self.career.save_career_and_skills(user_id, career_data, skills_data)

    async def ensure_career_exists(self, user_id: str) -> None:
        await self.career.ensure_career_exists(user_id)

    async def ensure_regeneration_allowed(self, user_id: str) -> None:
        await self.career.ensure_regeneration_allowed(user_id)

    async def check_regeneration_limit(self, user_id: str) -> dict:
        return await self.career.check_regeneration_limit(user_id)

    async def get_regeneration_status(self, user_id: str) -> dict:
        return await self.career.get_regeneration_status(user_id)

    async def add_phase(self, user_id: str, body):
        return await self.phases.add_phase(user_id, body)

    async def update_phase(self, phase_id: str, user_id: str, data: dict):
        return await self.phases.update_phase(phase_id, user_id, data)

    async def delete_phase(self, phase_id: str, user_id: str) -> None:
        await self.phases.delete_phase(phase_id, user_id)

    async def toggle_phase_complete(self, phase_id: str, user_id: str):
        return await self.phases.toggle_phase_complete(phase_id, user_id)

    async def toggle_action_complete(self, phase_id: str, user_id: str, action_index: int):
        return await self.phases.toggle_action_complete(phase_id, user_id, action_index)

    async def toggle_skill_complete(self, phase_id: str, user_id: str, skill_index: int):
        return await self.phases.toggle_skill_complete(phase_id, user_id, skill_index)

    async def reorder_phases(self, user_id: str, phase_ids: list[str]) -> None:
        await self.phases.reorder_phases(user_id, phase_ids)

    async def _get_completed_data(self, user_id: str) -> dict | None:
        roadmap = await self.repo.get_active_roadmap(user_id)
        if not roadmap:
            return None

        completed_phases = []
        acquired_skills = []
        completed_actions = []

        for phase in roadmap.phases:
            if phase.completed:
                completed_phases.append(phase.title)
            for skill in (phase.skills or []):
                if skill.get("completed"):
                    acquired_skills.append(skill.get("name", ""))
            for action in (phase.actions or []):
                if action.get("completed"):
                    completed_actions.append(action.get("task", ""))

        if not completed_phases and not acquired_skills and not completed_actions:
            return None

        return {
            "completed_phases": completed_phases,
            "acquired_skills": acquired_skills,
            "completed_actions": completed_actions,
        }

    async def _prepare_prompt(self, user_id: str):
        career = await self.career.get_career(user_id)
        if not career:
            raise ValueError("Career profile not found")

        skills = await self.career.get_skills(user_id)
        market_data = await self.career.get_market_data(
            career.target_jobs or [], career.city, career.province
        )
        completed_data = await self._get_completed_data(user_id)

        return build_roadmap_prompt(
            career_to_dict(career), skills, market_data, completed_data
        )

    async def _persist_roadmap(self, user_id: str, summary: dict | None, gpt_phases: list) -> None:
        await self.repo.archive_active(user_id)
        roadmap = await self.repo.create_roadmap(user_id, summary or None)
        await self.repo.create_phases(roadmap.id, _gpt_phases_to_rows(gpt_phases))
        await self.career.increment_regeneration_count(user_id)
        await self.repo.set_generation_status(user_id, "ready")

    async def generate(self, user_id: str) -> None:
        await self.repo.set_generation_status(user_id, "generating")
        await self.session.commit()

        try:
            system_prompt, user_prompt = await self._prepare_prompt(user_id)
            gpt_response = await call_gpt(system_prompt, user_prompt, user_id=user_id)

            summary = _extract_summary(gpt_response)
            gpt_phases = gpt_response.get("phases", [])

            await self._persist_roadmap(user_id, summary, gpt_phases)
            await self.session.commit()
            logger.info("Roadmap generated for user %s (%d phases)", user_id, len(gpt_phases))

        except Exception:
            logger.exception("Roadmap generation failed for user %s", user_id)
            await self.session.rollback()
            await self.repo.set_generation_status(user_id, "error")
            await self.session.commit()

    async def generate_stream(self, user_id: str):
        await self.repo.set_generation_status(user_id, "generating")
        await self.session.commit()

        try:
            system_prompt, user_prompt = await self._prepare_prompt(user_id)

            yield 'event: status\ndata: {"status":"generating"}\n\n'

            gpt_response = None
            async for event_type, data in generate_roadmap_stream(system_prompt, user_prompt, user_id=user_id):
                if event_type == "chunk":
                    yield f'event: chunk\ndata: {json.dumps({"text": data})}\n\n'
                elif event_type == "done":
                    gpt_response = data
                elif event_type == "error":
                    raise ValueError(data)

            if not gpt_response:
                raise ValueError("No response from GPT")

            summary = _extract_summary(gpt_response)
            gpt_phases = gpt_response.get("phases", [])

            await self._persist_roadmap(user_id, summary, gpt_phases)
            await self.session.commit()

            logger.info("Roadmap streamed for user %s (%d phases)", user_id, len(gpt_phases))
            yield 'event: complete\ndata: {"status":"ready"}\n\n'

        except Exception as e:
            logger.exception("Streaming roadmap generation failed for user %s", user_id)
            await self.session.rollback()
            await self.repo.set_generation_status(user_id, "error")
            await self.session.commit()
            yield f'event: error\ndata: {json.dumps({"error": str(e)})}\n\n'

    async def get_active(self, user_id: str):
        roadmap = await self.repo.get_active_roadmap(user_id)
        if not roadmap:
            raise NoActiveRoadmap()
        return roadmap

    async def get_history(self, user_id: str) -> list:
        return await self.repo.get_history(user_id)

    async def get_by_id(self, roadmap_id: str, user_id: str):
        roadmap = await self.repo.get_by_id(roadmap_id, user_id)
        if not roadmap:
            raise RoadmapNotFound()
        return roadmap

    async def create_manual_roadmap(self, user_id: str, phases_input: list):
        await self.repo.archive_active(user_id)
        roadmap = await self.repo.create_roadmap(user_id)

        phases_data = []
        for i, p in enumerate(phases_input):
            phase_dict = p.model_dump(exclude={"position"})
            phase_dict["phase_number"] = i + 1
            phase_dict["completed"] = False
            phase_dict["custom"] = True
            phase_dict["position"] = i
            phases_data.append(phase_dict)

        await self.repo.create_phases(roadmap.id, phases_data)
        await self.session.commit()

        return await self.repo.get_active_roadmap(user_id)

    async def archive_active_roadmap(self, user_id: str) -> None:
        roadmap = await self.repo.get_active_roadmap(user_id)
        if not roadmap:
            raise NoActiveRoadmap("No active roadmap to archive")
        await self.repo.archive_active(user_id)
        await self.session.commit()

    async def restore_roadmap(self, roadmap_id: str, user_id: str):
        roadmap = await self.repo.restore(roadmap_id, user_id)
        if not roadmap:
            raise NoArchivedRoadmap()
        await self.session.commit()
        return roadmap

    async def delete_roadmap(self, roadmap_id: str, user_id: str) -> None:
        deleted = await self.repo.delete_roadmap(roadmap_id, user_id)
        if not deleted:
            raise RoadmapNotFound()
        await self.session.commit()

    async def delete_all_archived(self, user_id: str) -> int:
        count = await self.repo.delete_all_archived(user_id)
        await self.session.commit()
        return count

    async def get_roadmap_status(self, user_id: str) -> dict:
        career = await self.career.get_career(user_id)
        roadmap = await self.repo.get_active_roadmap(user_id)
        return {
            "generation_status": career.generation_status if career else "idle",
            "has_roadmap": roadmap is not None,
        }


def _extract_summary(gpt_response: dict) -> dict:
    summary = {}
    for key in ("summary", "ai_strategy", "job_search_tips"):
        if key in gpt_response:
            summary[key] = gpt_response[key]
    return summary


def _gpt_phases_to_rows(gpt_phases: list) -> list[dict]:
    phases_data = []
    for i, p in enumerate(gpt_phases):
        for action in p.get("actions", []):
            action.setdefault("completed", False)
        for skill in p.get("skills", []):
            skill.setdefault("completed", False)

        phases_data.append({
            "phase_number": p.get("phase_number", i + 1),
            "title": p.get("title", f"Phase {i + 1}"),
            "duration_weeks": p.get("duration_weeks"),
            "objective": p.get("objective"),
            "milestone": p.get("milestone"),
            "completed": False,
            "custom": False,
            "user_notes": None,
            "position": i,
            "skills": p.get("skills", []),
            "actions": p.get("actions", []),
            "resources": p.get("resources", []),
            "certifications": p.get("certifications", []),
            "projects": p.get("projects", []),
        })
    return phases_data
