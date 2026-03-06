import logging

from core.database import AsyncSessionLocal
from services.analysis.jsearch_service import jsearch_service
from services.analysis.spacy_skills import spacy_extractor
from services.market.market_cache_service import MarketCacheService

logger = logging.getLogger(__name__)


async def refresh_market_cache() -> None:
    # Point d'entrée appelé par APScheduler 2x par jour (2h et 14h)
    logger.info("CRON: lancement du refresh market cache")
    async with AsyncSessionLocal() as session:
        try:
            svc = MarketCacheService(session, jsearch_service, spacy_extractor)
            summary = await svc.refresh_cache()
            logger.info("CRON: refresh terminé — %s", summary)
        except Exception:
            logger.exception("CRON: échec du refresh market cache")
            await session.rollback()
