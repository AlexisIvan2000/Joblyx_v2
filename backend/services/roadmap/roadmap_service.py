import logging
from datetime import datetime, timedelta, timezone

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from models.db_models import Career, UserSkill, MarketSkillsCache
from repositories.roadmap_repository import RoadmapRepository
from services.roadmap.prompt_builder import build_roadmap_prompt
from services.ai.openai_client import generate_roadmap as call_gpt

logger = logging.getLogger(__name__)

# Durée max du cache market pour être considéré valide
CACHE_MAX_AGE = timedelta(hours=48)


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
        # Cherche dans le cache pour chaque target_job, fusionne les résultats
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

            # Fusionne les skills de chaque job title
            for skill in cache.top_skills:
                name = skill["name"]
                if name in all_skills:
                    all_skills[name]["count"] += skill.get("count", 0)
                else:
                    all_skills[name] = {**skill}

        if not all_skills:
            return None

        # Trie par count décroissant
        return sorted(all_skills.values(), key=lambda s: s.get("count", 0), reverse=True)

    async def generate(self, user_id: str) -> None:
        """Génère un roadmap complet. Appelé en background task."""
        # Passe le status à 'generating'
        await self.repo.set_generation_status(user_id, "generating")
        await self.session.commit()

        try:
            # Lecture des données utilisateur
            career = await self._get_career(user_id)
            if not career:
                raise ValueError("Career profile not found")

            skills = await self._get_skills(user_id)

            # Récupération du cache marché
            market_data = await self._get_market_data(
                career.target_jobs or [], career.city, career.province
            )

            if market_data:
                logger.info("Cache marché trouvé pour user %s (%d skills)", user_id, len(market_data))
            else:
                logger.info("Pas de cache marché pour user %s — GPT utilisera ses connaissances", user_id)

            # Construction du prompt
            career_dict = {
                "level": career.level,
                "years_experience": career.years_experience,
                "target_jobs": career.target_jobs,
                "city": career.city,
                "province": career.province,
                "language": career.language,
                "previous_field": career.previous_field,
            }
            system_prompt, user_prompt = build_roadmap_prompt(career_dict, skills, market_data)

            # Appel GPT-4o
            gpt_response = await call_gpt(system_prompt, user_prompt)
            phases = gpt_response.get("phases", [])

            # Archive l'ancien roadmap actif s'il existe
            await self.repo.archive_active(user_id)

            # Sauvegarde le nouveau roadmap
            await self.repo.create(
                user_id=user_id,
                target_jobs=career.target_jobs or [],
                market_data=market_data,
                phases=phases,
            )

            # Status → 'ready'
            await self.repo.set_generation_status(user_id, "ready")
            await self.session.commit()
            logger.info("Roadmap généré avec succès pour user %s (%d phases)", user_id, len(phases))

        except Exception:
            logger.exception("Erreur génération roadmap pour user %s", user_id)
            await self.session.rollback()
            # Status → 'error'
            await self.repo.set_generation_status(user_id, "error")
            await self.session.commit()
