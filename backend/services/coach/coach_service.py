"""Service principal pour le coach IA — analyse CV vs offre."""

import hashlib
import json
from datetime import datetime, timezone, timedelta

import fitz  # PyMuPDF
from sqlalchemy.ext.asyncio import AsyncSession

from core.config import OPENAI_MODEL_FAST
from core.exceptions import (
    CoachWeeklyLimitReached,
    CvTextExtractionFailed,
    SessionNotFound,
)
from repositories.coach_repository import CoachRepository
from services.ai.openai_client import tracked_completion_stream
from services.coach.coach_prompt_builder import build_coach_prompt
from services.storage.r2_service import R2Service
from services.utils.text_cleaner import clean_cv_text

WEEKLY_LIMIT = 3


def _extract_text_from_pdf(pdf_bytes: bytes) -> str:
    doc = fitz.open(stream=pdf_bytes, filetype="pdf")
    text = ""
    for page in doc:
        text += page.get_text()
    doc.close()
    return text.strip()

# Retourne le prochain lundi à minuit UTC.
def _get_next_monday() -> datetime:
    now = datetime.now(timezone.utc)
    days_until_monday = (7 - now.weekday()) % 7
    if days_until_monday == 0:
        days_until_monday = 7
    return now.replace(hour=0, minute=0, second=0, microsecond=0) + timedelta(days=days_until_monday)

# Retourne le lundi de la semaine courante à minuit UTC
def _get_current_week_monday() -> datetime:
    now = datetime.now(timezone.utc)
    days_since_monday = now.weekday()
    return now.replace(hour=0, minute=0, second=0, microsecond=0) - timedelta(days=days_since_monday)


class CoachService:
    def __init__(self, session: AsyncSession):
        self.session = session
        self.repo = CoachRepository(session)
        self.r2 = R2Service()

    async def check_usage(self, user_id: str) -> dict:
        """Vérifie et retourne l'usage coach de la semaine."""
        usage = await self.repo.get_usage(user_id)
        count = usage["coach_usage_count"]
        reset_at = usage["coach_usage_reset_at"]

        # Vérifier si on est dans une nouvelle semaine (reset lundi à lundi)
        current_monday = _get_current_week_monday()
        if reset_at and reset_at < current_monday:
            count = 0
            await self.repo.reset_usage(user_id, current_monday)

        next_monday = _get_next_monday()
        return {
            "used": count,
            "limit": WEEKLY_LIMIT,
            "remaining": max(0, WEEKLY_LIMIT - count),
            "resets_at": next_monday.isoformat(),
        }

    async def analyze_stream(
        self,
        user_id: str,
        cv_bytes: bytes,
        cv_filename: str,
        job_description: str,
        job_title: str | None = None,
        company_name: str | None = None,
        language: str = "fr",
    ):
        """Analyse le CV vs l'offre via GPT en streaming.

        Yield (event_type, data) tuples :
          ("chunk", text)  — token brut du stream GPT
          ("done", analysis_dict)  — résultat final parsé
          ("error", error_msg)  — en cas d'erreur
        """
        # Vérifier la limite
        usage = await self.check_usage(user_id)
        if usage["remaining"] <= 0:
            raise CoachWeeklyLimitReached(
                details={"remaining": 0, "resets_at": usage["resets_at"]},
            )

        # Extraire et nettoyer le texte du CV
        cv_text = clean_cv_text(_extract_text_from_pdf(cv_bytes))
        if not cv_text:
            raise CvTextExtractionFailed()

        # Vérifier le cache avant d'appeler GPT
        cv_hash = hashlib.sha256(cv_text.encode()).hexdigest()
        job_hash = hashlib.sha256(job_description.encode()).hexdigest()
        cached = await self.repo.find_cached(user_id, cv_hash, job_hash)
        if cached and cached.analysis:
            yield ("done", cached.analysis)
            return

        # Upload le CV sur R2
        cv_file_key = await self.r2.upload_cv(user_id, cv_bytes, cv_filename)

        # Construire les prompts
        system_prompt, user_prompt = build_coach_prompt(cv_text, job_description, language)

        # Appel GPT en streaming, usage tracké via le wrapper
        accumulated = ""
        async for chunk in tracked_completion_stream(
            user_id=user_id,
            feature="coach",
            model=OPENAI_MODEL_FAST,
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_prompt},
            ],
            temperature=0.2,
            max_tokens=3000,
            response_format={"type": "json_object"},
        ):
            delta = chunk.choices[0].delta
            if delta.content:
                accumulated += delta.content
                yield ("chunk", delta.content)

        # Parser le résultat final
        try:
            analysis = json.loads(accumulated)
        except json.JSONDecodeError as e:
            yield ("error", f"Invalid JSON from GPT: {e}")
            return

        score = analysis.get("compatibility_score")

        # Sauvegarder en base
        await self.repo.create({
            "user_id": user_id,
            "job_title": job_title,
            "company_name": company_name,
            "job_description": job_description,
            "cv_file_key": cv_file_key,
            "cv_text": cv_text,
            "cv_hash": cv_hash,
            "job_description_hash": job_hash,
            "compatibility_score": score,
            "analysis": analysis,
            "language": language,
        })

        # Incrémenter le compteur d'usage
        await self.repo.increment_usage(user_id)
        await self.session.commit()

        yield ("done", analysis)

    async def get_session(self, session_id: str, user_id: str):
        session = await self.repo.get_by_id(session_id, user_id)
        if not session:
            raise SessionNotFound()
        return session

    async def get_history(self, user_id: str):
        return await self.repo.get_all_by_user(user_id)

    async def delete_session(self, session_id: str, user_id: str):
        session = await self.repo.delete_session(session_id, user_id)
        if not session:
            raise SessionNotFound()
        if session.cv_file_key:
            try:
                await self.r2.delete_cv(session.cv_file_key)
            except Exception:
                pass  # Ne pas bloquer la suppression si R2 échoue
        await self.session.commit()

    async def delete_all(self, user_id: str) -> int:
        keys = await self.repo.delete_all_by_user(user_id)
        for key in keys:
            try:
                await self.r2.delete_cv(key)
            except Exception:
                pass
        await self.session.commit()
        return len(keys)
