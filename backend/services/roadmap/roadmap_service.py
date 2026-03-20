import logging
from datetime import datetime, timedelta, timezone

from sqlalchemy import select, update, delete
from sqlalchemy.ext.asyncio import AsyncSession

from models.db_models import Career, UserSkill, MarketSkillsCache
from repositories.roadmap_repository import RoadmapRepository
from services.roadmap.prompt_builder import build_roadmap_prompt
from services.ai.openai_client import generate_roadmap as call_gpt

logger = logging.getLogger(__name__)

# Durée max du cache market pour être considéré valide
CACHE_MAX_AGE = timedelta(hours=48)

# Limite de régénérations par mois
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

    # ─── Sauvegarde career + skills (créer ou mettre à jour) ────────

    async def save_career_and_skills(self, user_id: str, career_data: dict, skills_data: list[dict]) -> bool:
        """Crée ou met à jour le profil career + user_skills.

        Retourne True si c'est la première création (pas de career existant).
        """
        career = await self._get_career(user_id)
        is_first = career is None

        if career:
            # Mise à jour du career existant
            await self.session.execute(
                update(Career).where(Career.user_id == user_id).values(**career_data)
            )
        else:
            # Création du career
            self.session.add(Career(user_id=user_id, **career_data))

        # Remplacer les skills : delete all + recreate
        await self.session.execute(
            delete(UserSkill).where(UserSkill.user_id == user_id)
        )
        if skills_data:
            self.session.add_all([UserSkill(user_id=user_id, **s) for s in skills_data])

        await self.session.flush()
        return is_first

    # ─── Vérification limite de régénération ─────────────────────────

    async def check_regeneration_limit(self, user_id: str) -> dict:
        """Vérifie et met à jour le compteur de régénération.

        Retourne {"allowed": bool, "used": int, "remaining": int, "resets_at": str}.
        """
        career = await self._get_career(user_id)
        if not career:
            return {"allowed": False, "used": 0, "remaining": 0, "resets_at": ""}

        now = datetime.now(timezone.utc)

        # Reset mensuel : si le mois courant est différent de celui du dernier reset
        reset_at = career.regeneration_reset_at
        if reset_at is None or (now.year, now.month) != (reset_at.year, reset_at.month):
            await self.session.execute(
                update(Career).where(Career.user_id == user_id).values(
                    regeneration_count=0,
                    regeneration_reset_at=now,
                )
            )
            await self.session.flush()
            # Refresh
            career = await self._get_career(user_id)

        used = career.regeneration_count or 0
        remaining = max(0, REGENERATION_LIMIT - used)

        # Date du 1er du mois prochain
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

    # ─── Génération du roadmap ───────────────────────────────────────

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

            # Ajoute completed/custom/user_notes par défaut sur chaque phase, action et skill
            for phase in phases:
                phase.setdefault("completed", False)
                phase.setdefault("custom", False)
                phase.setdefault("user_notes", None)
                for action in phase.get("actions", []):
                    action.setdefault("completed", False)
                for skill in phase.get("skills", []):
                    skill.setdefault("completed", False)

            # Archive l'ancien roadmap actif s'il existe
            await self.repo.archive_active(user_id)

            # Sauvegarde le nouveau roadmap
            await self.repo.create(
                user_id=user_id,
                target_jobs=career.target_jobs or [],
                market_data=market_data,
                phases=phases,
            )

            # Incrémente le compteur de régénération
            await self.increment_regeneration_count(user_id)

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

    # ─── Méthodes de modification (zéro appel GPT) ──────────────────

    async def update_phases(self, roadmap_id: str, user_id: str, phases: list[dict]):
        return await self.repo.update_phases(roadmap_id, user_id, phases)

    async def add_phase(self, roadmap_id: str, user_id: str, phase: dict, position: int | None):
        return await self.repo.add_phase(roadmap_id, user_id, phase, position)

    async def delete_phase(self, roadmap_id: str, user_id: str, phase_number: int):
        return await self.repo.delete_phase(roadmap_id, user_id, phase_number)

    async def toggle_phase_complete(self, roadmap_id: str, user_id: str, phase_number: int):
        return await self.repo.toggle_phase_complete(roadmap_id, user_id, phase_number)

    async def toggle_action_complete(self, roadmap_id: str, user_id: str, phase_number: int, action_index: int):
        return await self.repo.toggle_action_complete(roadmap_id, user_id, phase_number, action_index)
