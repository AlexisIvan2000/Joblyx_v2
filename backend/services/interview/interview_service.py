"""Service principal pour le simulateur d'entretien IA."""

import json
import logging
from datetime import datetime, timezone, timedelta

from sqlalchemy.ext.asyncio import AsyncSession

from core.config import OPENAI_MODEL_FAST
from core.exceptions import (
    InterviewDailyLimitReached,
    SessionAlreadyCompleted,
    SessionNotFound,
)
from repositories.interview_repository import InterviewRepository
from services.ai.openai_client import tracked_completion, tracked_completion_stream
from services.utils.text_cleaner import clean_cv_text
from services.interview.interview_prompt_builder import (
    build_interview_prompt,
    build_summary_prompt,
)

logger = logging.getLogger(__name__)

DAILY_LIMIT = 2
MAX_QUESTIONS = 15
MAX_MESSAGE_LENGTH = 2000
FEEDBACK_DELIMITER = "<<<FEEDBACK_JSON>>>"


def _get_tomorrow_midnight() -> datetime:
    """Retourne demain à minuit UTC."""
    now = datetime.now(timezone.utc)
    tomorrow = now.replace(hour=0, minute=0, second=0, microsecond=0) + timedelta(days=1)
    return tomorrow


def _get_today_midnight() -> datetime:
    """Retourne aujourd'hui à minuit UTC."""
    now = datetime.now(timezone.utc)
    return now.replace(hour=0, minute=0, second=0, microsecond=0)


class InterviewService:
    def __init__(self, session: AsyncSession):
        self.session = session
        self.repo = InterviewRepository(session)

    # ─── Usage ───────────────────────────────────────────────────

    async def check_usage(self, user_id: str) -> dict:
        usage = await self.repo.get_usage(user_id)
        count = usage["interview_usage_count"]
        reset_at = usage["interview_usage_reset_at"]

        # Reset si on est dans un nouveau jour
        today = _get_today_midnight()
        if reset_at and reset_at < today:
            count = 0
            await self.repo.reset_usage(user_id, today)

        tomorrow = _get_tomorrow_midnight()
        return {
            "used": count,
            "limit": DAILY_LIMIT,
            "remaining": max(0, DAILY_LIMIT - count),
            "resets_at": tomorrow.isoformat(),
        }

    #  Démarrer une session

    async def start_session(
        self,
        user_id: str,
        job_title: str,
        company_name: str | None = None,
        job_description: str | None = None,
        cv_text: str | None = None,
        language: str = "fr",
    ) -> dict:
        # Vérifier la limite
        usage = await self.check_usage(user_id)
        if usage["remaining"] <= 0:
            raise InterviewDailyLimitReached(
                f"Daily interview session limit reached ({DAILY_LIMIT} per day)",
                details={"remaining": 0, "resets_at": usage["resets_at"]},
            )

        # Nettoyer le CV
        if cv_text:
            cv_text = clean_cv_text(cv_text)

        # Créer la session
        interview = await self.repo.create_session({
            "user_id": user_id,
            "job_title": job_title,
            "company_name": company_name,
            "job_description": job_description,
            "cv_text": cv_text,
            "language": language,
        })

        # Construire le system prompt
        system_prompt = build_interview_prompt(
            job_title, company_name, job_description, cv_text, language
        )

        # Appeler GPT pour la première question (sans streaming pour le start)
        response = await tracked_completion(
            user_id=user_id,
            feature="interview_start",
            model=OPENAI_MODEL_FAST,
            messages=[{"role": "system", "content": system_prompt}],
            temperature=0.7,
            max_tokens=500,
        )

        raw_content = response.choices[0].message.content or ""
        message_text, feedback_data = _parse_response(raw_content)

        # Sauvegarder le message assistant
        await self.repo.create_message({
            "session_id": str(interview.id),
            "role": "assistant",
            "content": message_text,
            "feedback": feedback_data,
            "position": 1,
        })

        # Incrémenter l'usage
        await self.repo.increment_usage(user_id)
        await self.session.commit()

        return {
            "session_id": str(interview.id),
            "first_question": {
                "message": message_text,
                "question_type": feedback_data.get("question_type") if feedback_data else "introduction",
                "question_number": feedback_data.get("question_number", 1) if feedback_data else 1,
            },
        }

    # Envoyer un message (streaming via WebSocket)

    async def send_message_stream(
        self,
        session_id: str,
        user_id: str,
        user_message: str,
    ):
        """Yield des tuples (event_type, data) pour le streaming WebSocket.

        Events:
          ("stream", text_chunk) — texte à streamer dans le chat
          ("stream_end", None) — fin du texte
          ("feedback", feedback_dict) — feedback + metadata
          ("error", error_msg) — erreur
        """
        # Validations
        if not user_message or not user_message.strip():
            yield ("error", "Message vide")
            return
        if len(user_message) > MAX_MESSAGE_LENGTH:
            yield ("error", f"Message trop long (max {MAX_MESSAGE_LENGTH} caractères)")
            return

        # Vérifier la session
        interview = await self.repo.get_session_by_id(session_id, user_id)
        if not interview:
            yield ("error", "Session introuvable")
            return
        if interview.status != "in_progress":
            yield ("error", "Entretien terminé")
            return

        # Sauvegarder le message utilisateur
        messages = await self.repo.get_messages_by_session(session_id)

        # Compter uniquement les vraies questions (counts_as_question=true)
        real_question_count = 0
        for m in messages:
            if m.role == "assistant" and m.feedback:
                fb = m.feedback if isinstance(m.feedback, dict) else {}
                if fb.get("counts_as_question", True):
                    real_question_count += 1
        user_position = len(messages) + 1
        await self.repo.create_message({
            "session_id": session_id,
            "role": "user",
            "content": user_message.strip(),
            "feedback": None,
            "position": user_position,
        })

        # Construire l'historique pour GPT (fenêtre glissante pour réduire les tokens)
        system_prompt = build_interview_prompt(
            interview.job_title,
            interview.company_name,
            interview.job_description,
            interview.cv_text,
            interview.language or "fr",
        )
        gpt_messages = [{"role": "system", "content": system_prompt}]
        gpt_messages.extend(_build_windowed_history(messages))

        # Validation hors contexte : message court qui ressemble à une question factuelle
        clean_msg = user_message.strip()
        if len(clean_msg) < 60 and clean_msg.endswith("?") and not any(
            kw in clean_msg.lower() for kw in ["entretien", "poste", "équipe", "projet", "expérience", "entreprise"]
        ):
            gpt_messages.append({"role": "system", "content": "[SYSTÈME : le candidat semble poser une question hors contexte. Redirige-le vers l'entretien sans répondre à sa question.]"})

        gpt_messages.append({"role": "user", "content": clean_msg})

        # Forcer la clôture si on atteint la limite
        if real_question_count >= MAX_QUESTIONS - 1:
            gpt_messages.append({
                "role": "system",
                "content": "C'est la dernière question. Remercie le candidat et clôture l'entretien. question_type=closing, question_number=15."
            })

        # Appeler GPT en streaming, usage tracké via le wrapper
        # full_text accumule le message COMPLET pour la sauvegarde en base
        # accumulated est le buffer de streaming (trimé après chaque envoi)
        full_text = ""
        accumulated = ""
        streaming_text = True

        async for chunk in tracked_completion_stream(
            user_id=user_id,
            feature="interview_turn",
            model=OPENAI_MODEL_FAST,
            messages=gpt_messages,
            temperature=0.7,
            max_tokens=500,
        ):
            delta = chunk.choices[0].delta
            if delta.content:
                full_text += delta.content
                accumulated += delta.content

                if streaming_text:
                    # Vérifier si le délimiteur est arrivé
                    if FEEDBACK_DELIMITER in full_text:
                        # Envoyer le texte restant avant le délimiteur
                        remaining = accumulated.split(FEEDBACK_DELIMITER, 1)[0]
                        if remaining:
                            yield ("stream", remaining)
                        streaming_text = False
                    else:
                        # Streamer le texte (mais garder un buffer pour ne pas couper le délimiteur)
                        safe_end = len(accumulated) - len(FEEDBACK_DELIMITER)
                        if safe_end > 0:
                            to_send = accumulated[:safe_end]
                            if to_send:
                                yield ("stream", to_send)
                                accumulated = accumulated[safe_end:]

        # Traitement final — utiliser full_text pour extraire le message complet
        if FEEDBACK_DELIMITER in full_text:
            parts = full_text.split(FEEDBACK_DELIMITER, 1)
            full_message = parts[0].rstrip()

            # Envoyer le texte encore dans le buffer si nécessaire
            if streaming_text and accumulated:
                remaining = accumulated.split(FEEDBACK_DELIMITER, 1)[0]
                if remaining:
                    yield ("stream", remaining)

            yield ("stream_end", None)

            # Parser le feedback JSON
            feedback_raw = parts[1].strip()
            try:
                feedback_data = json.loads(feedback_raw)
            except json.JSONDecodeError:
                feedback_data = {"feedback": None, "question_type": "unknown", "question_number": real_question_count + 1, "counts_as_question": True}
        else:
            # Pas de délimiteur trouvé — envoyer tout le texte restant
            if accumulated:
                yield ("stream", accumulated)
            yield ("stream_end", None)
            full_message = full_text.rstrip()
            feedback_data = {"feedback": None, "question_type": "unknown", "question_number": real_question_count + 1, "counts_as_question": True}

        logger.info("Saving message: %d chars for session %s", len(full_message), session_id)

        # Sauvegarder le message assistant
        assistant_position = user_position + 1
        await self.repo.create_message({
            "session_id": session_id,
            "role": "assistant",
            "content": full_message,
            "feedback": feedback_data,
            "position": assistant_position,
        })

        question_type = feedback_data.get("question_type", "")
        counts = feedback_data.get("counts_as_question", True)
        question_number = feedback_data.get("question_number", real_question_count + 1)

        # Protéger contre une clôture prématurée par l'IA
        if question_type == "closing" and real_question_count < 12:
            question_type = feedback_data["question_type"] = "behavioral"
            feedback_data["counts_as_question"] = True
            counts = True
            logger.warning("Blocked premature closing at question %d for session %s", real_question_count, session_id)

        is_last = question_type == "closing" or (counts and question_number >= MAX_QUESTIONS)

        yield ("feedback", {
            **feedback_data,
            "is_last": is_last,
        })

        # Générer le bilan si c'est la fin
        if is_last:
            await self.session.commit()
            summary = await self._generate_summary(session_id, user_id, interview.language or "fr")
            yield ("summary", summary)

        await self.session.commit()

    # Terminer en avance 

    async def end_session_early(self, session_id: str, user_id: str) -> dict:
        """Force la fin de l'entretien. Envoie 'Avez-vous des questions ?' puis clôture."""
        interview = await self.repo.get_session_by_id(session_id, user_id)
        if not interview:
            raise SessionNotFound()
        if interview.status != "in_progress":
            raise SessionAlreadyCompleted()

        messages = await self.repo.get_messages_by_session(session_id)
        system_prompt = build_interview_prompt(
            interview.job_title, interview.company_name,
            interview.job_description, interview.cv_text,
            interview.language or "fr",
        )

        gpt_messages = [{"role": "system", "content": system_prompt}]
        for msg in messages:
            gpt_messages.append({"role": msg.role, "content": msg.content})
        gpt_messages.append({
            "role": "system",
            "content": "Le candidat souhaite terminer l'entretien. Pose-lui 'Avez-vous des questions sur le poste ou l'entreprise ?' puis clôture. question_type=candidate_questions puis closing."
        })

        response = await tracked_completion(
            user_id=user_id,
            feature="interview_end_early",
            model=OPENAI_MODEL_FAST,
            messages=gpt_messages,
            temperature=0.7,
            max_tokens=500,
        )

        raw_content = response.choices[0].message.content or ""
        message_text, feedback_data = _parse_response(raw_content)

        position = len(messages) + 1
        await self.repo.create_message({
            "session_id": session_id,
            "role": "assistant",
            "content": message_text,
            "feedback": feedback_data,
            "position": position,
        })
        await self.session.commit()

        return {
            "message": message_text,
            "feedback": feedback_data,
            "is_last": False,  # L'utilisateur doit encore répondre à "avez-vous des questions"
        }

    #  Bilan

    async def _generate_summary(self, session_id: str, user_id: str, language: str) -> dict:
        messages = await self.repo.get_messages_by_session(session_id)

        # Construire l'historique complet
        history = "\n\n".join(
            f"{'Recruteur' if m.role == 'assistant' else 'Candidat'}: {m.content}"
            for m in messages
        )

        summary_prompt = build_summary_prompt(language)

        response = await tracked_completion(
            user_id=user_id,
            feature="interview_summary",
            model=OPENAI_MODEL_FAST,
            messages=[
                {"role": "system", "content": summary_prompt},
                {"role": "user", "content": f"Voici la transcription de l'entretien :\n\n{history}"},
            ],
            temperature=0.2,
            max_tokens=1500,
            response_format={"type": "json_object"},
        )

        content = response.choices[0].message.content or "{}"
        try:
            summary = json.loads(content)
        except json.JSONDecodeError:
            summary = {"overall_score": 0, "summary": "Erreur lors de la génération du bilan."}

        # Mettre à jour la session
        await self.repo.update_session(session_id, {
            "status": "completed",
            "overall_score": summary.get("overall_score"),
            "category_scores": summary.get("category_scores"),
            "summary": summary.get("summary"),
            "completed_at": datetime.now(timezone.utc),
        })
        await self.session.commit()

        return summary

    # CRUD 

    async def get_session(self, session_id: str, user_id: str):
        session = await self.repo.get_session_by_id(session_id, user_id)
        if not session:
            raise SessionNotFound()
        return session

    async def get_history(self, user_id: str):
        return await self.repo.get_sessions_by_user(user_id)

    async def delete_session(self, session_id: str, user_id: str):
        deleted = await self.repo.delete_session(session_id, user_id)
        if not deleted:
            raise SessionNotFound()
        await self.session.commit()

    async def delete_all(self, user_id: str) -> int:
        count = await self.repo.delete_all_by_user(user_id)
        await self.session.commit()
        return count


_WINDOW_SIZE = 10  # Nombre de messages récents à garder


def _build_windowed_history(messages: list) -> list[dict]:
    """Construit un historique tronqué pour économiser les tokens.

    Garde les 2 premiers messages (intro) + les N derniers.
    Résume les messages du milieu en une ligne.
    """
    if len(messages) <= _WINDOW_SIZE + 2:
        # Pas besoin de tronquer
        return [{"role": m.role, "content": m.content} for m in messages]

    # Premiers messages (intro)
    intro = messages[:2]
    # Derniers messages (fenêtre récente)
    recent = messages[-_WINDOW_SIZE:]
    # Messages du milieu (résumés)
    middle = messages[2:-_WINDOW_SIZE]
    middle_topics = set()
    for m in middle:
        if m.role == "assistant":
            # Extraire les premiers mots comme topic
            words = m.content.split()[:6]
            middle_topics.add(" ".join(words))

    result = [{"role": m.role, "content": m.content} for m in intro]

    if middle:
        summary = f"[{len(middle)} messages précédents résumés : le candidat a répondu à {len(middle) // 2} questions supplémentaires]"
        result.append({"role": "system", "content": summary})

    result.extend({"role": m.role, "content": m.content} for m in recent)
    return result

# Parse la réponse GPT en séparant le texte et le feedback JSON.
def _parse_response(raw: str) -> tuple[str, dict | None]:
    if FEEDBACK_DELIMITER in raw:
        parts = raw.split(FEEDBACK_DELIMITER, 1)
        message_text = parts[0].rstrip()
        try:
            feedback_data = json.loads(parts[1].strip())
        except json.JSONDecodeError:
            feedback_data = None
        return message_text, feedback_data
    return raw, None
