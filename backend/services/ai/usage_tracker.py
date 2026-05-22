"""Tracker des appels OpenAI : persiste un log par appel avec tokens et coût réel.

Utilisé via les wrappers de openai_client.py. Best effort : un échec d'écriture ne casse
jamais le flux métier (on log et on continue), mais on conserve le coût même si la
transaction métier rollback (commit dédié sur une nouvelle session).
"""

import logging
from typing import Any

from core.database import AsyncSessionLocal
from models.db.openai_usage import OpenAIUsageLog
from services.ai.pricing import calculate_cost

logger = logging.getLogger(__name__)

# Session dédiée au tracking, isolée du flux métier, on ne dépend pas du commit
# du service appelant (les tokens sont déjà facturés par OpenAI, on doit les enregistrer)
_TrackerSession = AsyncSessionLocal


def _extract_usage(usage_obj: Any) -> tuple[int, int, int]:
    """Extrait (prompt_tokens, completion_tokens, total_tokens) depuis un objet usage OpenAI."""
    if usage_obj is None:
        return (0, 0, 0)
    prompt = getattr(usage_obj, "prompt_tokens", 0) or 0
    completion = getattr(usage_obj, "completion_tokens", 0) or 0
    total = getattr(usage_obj, "total_tokens", 0) or (prompt + completion)
    return (int(prompt), int(completion), int(total))


async def track_usage(
    *,
    user_id: str | None,
    feature: str,
    model: str,
    usage: Any,
) -> None:
    """Persiste un log d'appel OpenAI dans sa propre transaction, best effort."""
    prompt, completion, total = _extract_usage(usage)
    if total == 0:
        # Pas d'usage à logger, ne pas créer de row vide
        return

    cost = calculate_cost(model, prompt, completion)

    try:
        async with _TrackerSession() as session:
            log = OpenAIUsageLog(
                user_id=user_id,
                feature=feature,
                model=model,
                prompt_tokens=prompt,
                completion_tokens=completion,
                total_tokens=total,
                cost_usd=cost,
            )
            session.add(log)
            await session.commit()
        logger.info(
            "OpenAI usage tracked: user=%s feature=%s model=%s tokens=%d cost=$%s",
            user_id, feature, model, total, cost,
        )
    except Exception as exc:
        # On ne casse jamais le flux métier sur un échec de tracking
        logger.error(
            "Failed to track OpenAI usage: user=%s feature=%s error=%s",
            user_id, feature, exc,
        )
