import json
import logging
from datetime import datetime, timezone
from pathlib import Path

from sqlalchemy import select
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.ext.asyncio import AsyncSession

from models.db_models import Career, MarketSkillsCache
from services.analysis.jsearch_service import JSearchService
from services.analysis.spacy_skills import SpacySkillsExtractor

logger = logging.getLogger(__name__)

# Villes IT canadiennes principales
CANADIAN_IT_CITIES = [
    ("Toronto", "ON"),
    ("Montreal", "QC"),
    ("Vancouver", "BC"),
    ("Ottawa", "ON"),
    ("Calgary", "AB"),
    ("Edmonton", "AB"),
    ("Quebec City", "QC"),
    ("Winnipeg", "MB"),
    ("Halifax", "NS"),
    ("Mississauga", "ON"),
    ("Waterloo", "ON"),
]


class MarketCacheService:
    def __init__(
        self,
        session: AsyncSession,
        jsearch: JSearchService,
        extractor: SpacySkillsExtractor,
    ):
        self.session = session
        self.jsearch = jsearch
        self.extractor = extractor

    def _load_job_titles(self) -> list[str]:
        # Charge la liste des job titles IT depuis le référentiel
        path = Path(__file__).parent.parent.parent / "models" / "data" / "job_titles_it.json"
        with open(path, "r", encoding="utf-8") as f:
            return json.load(f)

    def _build_predefined_combos(self) -> set[tuple[str, str, str]]:
        # Produit cartésien job_titles × villes canadiennes
        job_titles = self._load_job_titles()
        combos = set()
        for title in job_titles:
            for city, province in CANADIAN_IT_CITIES:
                combos.add((title.strip(), city, province))
        return combos

    async def _get_career_combos(self) -> set[tuple[str, str, str]]:
        # Récupère les combos uniques depuis la table career
        result = await self.session.execute(
            select(Career.target_jobs, Career.city, Career.province)
        )
        combos = set()
        for row in result.all():
            target_jobs, city, province = row
            if not target_jobs:
                continue
            for job in target_jobs:
                j = job.strip()
                if j:
                    combos.add((j, city.strip(), province.strip()))
        return combos

    async def _upsert_cache(
        self, job_title: str, city: str, province: str,
        top_skills: list[dict], job_count: int,
    ) -> None:
        # Insert ou update dans market_skills_cache
        now = datetime.now(timezone.utc)
        stmt = pg_insert(MarketSkillsCache).values(
            job_title=job_title,
            city=city,
            province=province,
            top_skills=top_skills,
            job_count=job_count,
            fetched_at=now,
        ).on_conflict_do_update(
            index_elements=["job_title", "city", "province"],
            set_={
                "top_skills": top_skills,
                "job_count": job_count,
                "fetched_at": now,
            },
        )
        await self.session.execute(stmt)

    async def refresh_cache(self) -> dict:
        # Source 1 : combos prédéfinies (job_titles_it.json × villes IT)
        predefined = self._build_predefined_combos()
        logger.info("Source 1 (prédéfinie) : %d combos", len(predefined))

        # Source 2 : combos depuis la table career (utilisateurs)
        career_combos = await self._get_career_combos()
        logger.info("Source 2 (career) : %d combos", len(career_combos))

        # Fusion et déduplication (career ajoute celles qui manquent)
        all_combos = predefined | career_combos
        extra = len(all_combos) - len(predefined)
        logger.info("Total après déduplication : %d combos (%d extras depuis career)", len(all_combos), extra)

        processed = 0
        skipped = 0

        for job_title, city, province in all_combos:
            location = f"{city}, {province}, Canada"

            try:
                # Appel JSearch pour récupérer les descriptions d'offres
                descriptions = await self.jsearch.get_job_descriptions(
                    query=job_title, location=location, num_pages=3
                )

                if not descriptions:
                    logger.warning("Aucune description pour '%s' à %s", job_title, location)
                    skipped += 1
                    continue

                # Extraction et classement des skills par fréquence
                ranked_skills = await self.extractor.extract_and_rank(descriptions)

                # Upsert dans le cache
                await self._upsert_cache(
                    job_title=job_title,
                    city=city,
                    province=province,
                    top_skills=ranked_skills,
                    job_count=len(descriptions),
                )
                processed += 1
                logger.info(
                    "Caché %d skills pour '%s' à %s (%d offres)",
                    len(ranked_skills), job_title, location, len(descriptions),
                )

            except Exception:
                logger.exception("Erreur pour '%s' à %s", job_title, location)
                skipped += 1

        await self.session.commit()
        summary = {"processed": processed, "skipped": skipped, "total": len(all_combos)}
        logger.info("Refresh terminé : %s", summary)
        return summary
