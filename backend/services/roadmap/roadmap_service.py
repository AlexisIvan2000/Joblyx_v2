import copy
import json
import logging
from datetime import datetime, timedelta, timezone

from sqlalchemy.ext.asyncio import AsyncSession

from core.exceptions import (
    ActionNotFound,
    CareerProfileRequired,
    InvalidPhaseIdsForReorder,
    NoActiveRoadmap,
    NoArchivedRoadmap,
    PhaseNotFound,
    RoadmapNotFound,
    RoadmapRegenerationLimitReached,
    SkillIndexNotFound,
)
from repositories.career_repository import CareerRepository
from repositories.roadmap_repository import RoadmapRepository
from services.roadmap.prompt_builder import build_roadmap_prompt
from services.ai.openai_client import generate_roadmap as call_gpt, generate_roadmap_stream

logger = logging.getLogger(__name__)

CACHE_MAX_AGE = timedelta(hours=48)
REGENERATION_LIMIT = 5


class RoadmapService:
    def __init__(self, session: AsyncSession):
        self.session = session
        self.repo = RoadmapRepository(session)
        self.career_repo = CareerRepository(session)

    async def _get_career(self, user_id: str):
        return await self.career_repo.get_by_user_id(user_id)

    async def _get_skills(self, user_id: str) -> list[dict]:
        skills = await self.career_repo.get_skills(user_id)
        return [
            {"skill_name": s.skill_name, "category": s.category, "proficiency": s.proficiency}
            for s in skills
        ]

    async def _get_market_data(self, target_jobs: list[str], city: str, province: str) -> list[dict] | None:
        if not target_jobs:
            return None
        cutoff = datetime.now(timezone.utc) - CACHE_MAX_AGE
        caches = await self.career_repo.get_market_skills(target_jobs, city, province, cutoff)

        # Agrège les top_skills de toutes les caches (somme des counts par nom de skill)
        all_skills: dict[str, dict] = {}
        for cache in caches:
            for skill in cache.top_skills:
                name = skill["name"]
                if name in all_skills:
                    all_skills[name]["count"] += skill.get("count", 0)
                else:
                    all_skills[name] = {**skill}

        if not all_skills:
            return None
        return sorted(all_skills.values(), key=lambda s: s.get("count", 0), reverse=True)

    # Sauvegarde career + skills

    async def save_career_and_skills(self, user_id: str, career_data: dict, skills_data: list[dict]) -> bool:
        is_first = await self.career_repo.upsert(user_id, career_data)
        await self.career_repo.replace_skills(user_id, skills_data)
        return is_first

    #  Regeneration limit 

    async def check_regeneration_limit(self, user_id: str) -> dict:
        career = await self._get_career(user_id)
        if not career:
            now = datetime.now(timezone.utc)
            if now.month == 12:
                next_reset = datetime(now.year + 1, 1, 1, tzinfo=timezone.utc)
            else:
                next_reset = datetime(now.year, now.month + 1, 1, tzinfo=timezone.utc)
            return {"allowed": True, "used": 0, "remaining": REGENERATION_LIMIT, "resets_at": next_reset.isoformat()}

        now = datetime.now(timezone.utc)
        reset_at = career.regeneration_reset_at
        if reset_at is None or (now.year, now.month) != (reset_at.year, reset_at.month):
            await self.career_repo.reset_regeneration_counter(user_id, now)
            career = await self._get_career(user_id)

        used = career.regeneration_count or 0
        remaining = max(0, REGENERATION_LIMIT - used)

        if now.month == 12:
            next_reset = datetime(now.year + 1, 1, 1, tzinfo=timezone.utc)
        else:
            next_reset = datetime(now.year, now.month + 1, 1, tzinfo=timezone.utc)

        return {
            "allowed": used < REGENERATION_LIMIT,
            "used": used,
            "remaining": remaining,
            "resets_at": next_reset.isoformat(),
        }

    async def increment_regeneration_count(self, user_id: str) -> None:
        await self.career_repo.increment_regeneration_count(user_id)

    # Collecte des données de progression pour le prompt (phases complétées, compétences acquises, actions réalisées)

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

    #  Generation

    async def generate(self, user_id: str) -> None:
        await self.repo.set_generation_status(user_id, "generating")
        await self.session.commit()

        try:
            career = await self._get_career(user_id)
            if not career:
                raise ValueError("Career profile not found")

            skills = await self._get_skills(user_id)
            market_data = await self._get_market_data(
                career.target_jobs or [], career.city, career.province
            )

            # Collect progress from existing roadmap for the prompt
            completed_data = await self._get_completed_data(user_id)

            career_dict = {
                "level": career.level,
                "years_experience": career.years_experience,
                "target_jobs": career.target_jobs,
                "city": career.city,
                "province": career.province,
                "language": career.language,
                "previous_field": career.previous_field,
            }
            system_prompt, user_prompt = build_roadmap_prompt(
                career_dict, skills, market_data, completed_data
            )

            gpt_response = await call_gpt(system_prompt, user_prompt, user_id=user_id)

            # Extract summary from GPT response
            summary = {}
            for key in ("summary", "ai_strategy", "job_search_tips"):
                if key in gpt_response:
                    summary[key] = gpt_response[key]

            gpt_phases = gpt_response.get("phases", [])

            # Archive old roadmap
            await self.repo.archive_active(user_id)

            # Create new roadmap
            roadmap = await self.repo.create_roadmap(user_id, summary or None)

            # Transform GPT phases into RoadmapPhase rows
            phases_data = []
            for i, p in enumerate(gpt_phases):
                # Add completed defaults to JSONB sub-items
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

            await self.repo.create_phases(roadmap.id, phases_data)

            await self.increment_regeneration_count(user_id)
            await self.repo.set_generation_status(user_id, "ready")
            await self.session.commit()
            logger.info("Roadmap generated for user %s (%d phases)", user_id, len(gpt_phases))

        except Exception:
            logger.exception("Roadmap generation failed for user %s", user_id)
            await self.session.rollback()
            await self.repo.set_generation_status(user_id, "error")
            await self.session.commit()

    #  Streaming generation 
    # Génère une roadmap via streaming. Yields des strings formatées pour SSE
    async def generate_stream(self, user_id: str):
       
        await self.repo.set_generation_status(user_id, "generating")
        await self.session.commit()

        try:
            career = await self._get_career(user_id)
            if not career:
                raise ValueError("Career profile not found")

            skills = await self._get_skills(user_id)
            market_data = await self._get_market_data(
                career.target_jobs or [], career.city, career.province
            )
            completed_data = await self._get_completed_data(user_id)

            career_dict = {
                "level": career.level,
                "years_experience": career.years_experience,
                "target_jobs": career.target_jobs,
                "city": career.city,
                "province": career.province,
                "language": career.language,
                "previous_field": career.previous_field,
            }
            system_prompt, user_prompt = build_roadmap_prompt(
                career_dict, skills, market_data, completed_data
            )

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

            # Sommaire de la roadmap pour affichage avant les phases détaillées
            summary = {}
            for key in ("summary", "ai_strategy", "job_search_tips"):
                if key in gpt_response:
                    summary[key] = gpt_response[key]

            gpt_phases = gpt_response.get("phases", [])

            # Archive l'ancienne roadmap et crée la nouvelle avec les phases détaillées
            await self.repo.archive_active(user_id)
            roadmap = await self.repo.create_roadmap(user_id, summary or None)

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

            await self.repo.create_phases(roadmap.id, phases_data)
            await self.increment_regeneration_count(user_id)
            await self.repo.set_generation_status(user_id, "ready")
            await self.session.commit()

            logger.info("Roadmap streamed for user %s (%d phases)", user_id, len(gpt_phases))
            yield 'event: complete\ndata: {"status":"ready"}\n\n'

        except Exception as e:
            logger.exception("Streaming roadmap generation failed for user %s", user_id)
            await self.session.rollback()
            await self.repo.set_generation_status(user_id, "error")
            await self.session.commit()
            yield f'event: error\ndata: {json.dumps({"error": str(e)})}\n\n'

    # Profil career récupération + update

    async def get_career_profile(self, user_id: str) -> dict:
        career = await self._get_career(user_id)
        if not career:
            raise CareerProfileRequired()
        skills = await self._get_skills(user_id)
        return {
            "level": career.level,
            "years_experience": career.years_experience,
            "target_jobs": career.target_jobs or [],
            "city": career.city,
            "province": career.province,
            "language": career.language,
            "previous_field": career.previous_field,
            "skills": skills,
        }

    async def update_career_profile(self, user_id: str, body) -> dict:
        career = await self._get_career(user_id)

        # Construit le dict d'update à partir des champs non-None
        career_updates: dict = {}
        for field in ("level", "years_experience", "target_jobs", "city", "province", "language", "previous_field"):
            val = getattr(body, field, None)
            if val is not None:
                career_updates[field] = val.value if hasattr(val, "value") else val

        if not career:
            # Crée le profil pour les utilisateurs sans onboarding préalable
            await self.career_repo.create(user_id, career_updates)
        elif career_updates:
            await self.career_repo.update_fields(user_id, career_updates)

        # Met à jour les skills si fournis (None = ne pas toucher aux skills existants)
        if body.skills is not None:
            skills_data = [
                {"skill_name": s.skill_name, "category": s.category, "proficiency": s.proficiency.value}
                for s in body.skills
            ]
            await self.career_repo.replace_skills(user_id, skills_data)

        await self.session.commit()
        return await self.get_career_profile(user_id)

    async def ensure_career_exists(self, user_id: str) -> None:
        career = await self._get_career(user_id)
        if not career:
            raise CareerProfileRequired()

    async def ensure_regeneration_allowed(self, user_id: str) -> None:
        regen = await self.check_regeneration_limit(user_id)
        if not regen["allowed"]:
            raise RoadmapRegenerationLimitReached(
                details={"remaining": 0, "resets_at": regen["resets_at"]},
            )

    # Roadmap CRUD

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

        # Recharge avec les phases
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

    # Phases

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

    async def get_roadmap_status(self, user_id: str) -> dict:
        career = await self._get_career(user_id)
        roadmap = await self.repo.get_active_roadmap(user_id)
        return {
            "generation_status": career.generation_status if career else "idle",
            "has_roadmap": roadmap is not None,
        }

    async def get_regeneration_status(self, user_id: str) -> dict:
        regen = await self.check_regeneration_limit(user_id)
        return {
            "used": regen["used"],
            "limit": REGENERATION_LIMIT,
            "remaining": regen["remaining"],
            "resets_at": regen["resets_at"],
        }
