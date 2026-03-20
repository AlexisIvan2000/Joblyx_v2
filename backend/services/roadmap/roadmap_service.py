import json
import logging
from datetime import datetime, timedelta, timezone

from sqlalchemy import select, update, delete
from sqlalchemy.ext.asyncio import AsyncSession

from models.db_models import Career, UserSkill, MarketSkillsCache
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

    async def _get_career(self, user_id: str) -> Career:
        result = await self.session.execute(
            select(Career).where(Career.user_id == user_id)
        )
        return result.scalar_one_or_none()

    async def _get_skills(self, user_id: str) -> list[dict]:
        result = await self.session.execute(
            select(UserSkill).where(UserSkill.user_id == user_id)
        )
        return [
            {"skill_name": s.skill_name, "category": s.category, "proficiency": s.proficiency}
            for s in result.scalars().all()
        ]

    async def _get_market_data(self, target_jobs: list[str], city: str, province: str) -> list[dict] | None:
        cutoff = datetime.now(timezone.utc) - CACHE_MAX_AGE
        all_skills = {}

        for job in target_jobs:
            result = await self.session.execute(
                select(MarketSkillsCache).where(
                    MarketSkillsCache.job_title == job,
                    MarketSkillsCache.city == city,
                    MarketSkillsCache.province == province,
                    MarketSkillsCache.fetched_at >= cutoff,
                )
            )
            cache = result.scalar_one_or_none()
            if not cache:
                continue
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
        career = await self._get_career(user_id)
        is_first = career is None

        if career:
            await self.session.execute(
                update(Career).where(Career.user_id == user_id).values(**career_data)
            )
        else:
            self.session.add(Career(user_id=user_id, **career_data))

        await self.session.execute(
            delete(UserSkill).where(UserSkill.user_id == user_id)
        )
        if skills_data:
            self.session.add_all([UserSkill(user_id=user_id, **s) for s in skills_data])

        await self.session.flush()
        return is_first

    #  Regeneration limit 

    async def check_regeneration_limit(self, user_id: str) -> dict:
        career = await self._get_career(user_id)
        if not career:
            return {"allowed": False, "used": 0, "remaining": 0, "resets_at": ""}

        now = datetime.now(timezone.utc)
        reset_at = career.regeneration_reset_at
        if reset_at is None or (now.year, now.month) != (reset_at.year, reset_at.month):
            await self.session.execute(
                update(Career).where(Career.user_id == user_id).values(
                    regeneration_count=0, regeneration_reset_at=now,
                )
            )
            await self.session.flush()
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
        await self.session.execute(
            update(Career).where(Career.user_id == user_id).values(
                regeneration_count=Career.regeneration_count + 1,
            )
        )
        await self.session.flush()

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

            gpt_response = await call_gpt(system_prompt, user_prompt)

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
            async for event_type, data in generate_roadmap_stream(system_prompt, user_prompt):
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
