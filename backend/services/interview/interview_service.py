"""Service principal pour le simulateur d'entretien IA."""

import json
import logging
from datetime import datetime, timezone, timedelta

from fastapi import HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from repositories.interview_repository import InterviewRepository
from services.ai.openai_client import client
from services.interview.interview_prompt_builder import (
    build_interview_prompt,
    build_summary_prompt,
)

logger = logging.getLogger(__name__)

DAILY_LIMIT = 1
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

    # ─── Démarrer une session ────────────────────────────────────

    async def start_session(
        self,
        user_id: str,
        job_title: str,
        company_name: str | None = None,
        job_description: str | None = None,
        language: str = "fr",
    ) -> dict:
        # Vérifier la limite
        usage = await self.check_usage(user_id)
        if usage["remaining"] <= 0:
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail={
                    "error": "Limite de 1 session par jour atteinte",
                    "remaining": 0,
                    "resets_at": usage["resets_at"],
                },
            )

        # Créer la session
        interview = await self.repo.create_session({
            "user_id": user_id,
            "job_title": job_title,
            "company_name": company_name,
            "job_description": job_description,
            "language": language,
        })

        # Construire le system prompt
        system_prompt = build_interview_prompt(
            job_title, company_name, job_description, language
        )

        # Appeler GPT pour la première question (sans streaming pour le start)
        response = await client.chat.completions.create(
            model="gpt-4o-mini",
            messages=[{"role": "system", "content": system_prompt}],
            temperature=0.7,
            max_tokens=800,
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

    # ─── Envoyer un message (streaming via WebSocket) ────────────

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

        # Compter les messages assistant existants
        assistant_count = await self.repo.count_assistant_messages(session_id)

        # Sauvegarder le message utilisateur
        messages = await self.repo.get_messages_by_session(session_id)
        user_position = len(messages) + 1
        await self.repo.create_message({
            "session_id": session_id,
            "role": "user",
            "content": user_message.strip(),
            "feedback": None,
            "position": user_position,
        })

        # Construire l'historique pour GPT
        system_prompt = build_interview_prompt(
            interview.job_title,
            interview.company_name,
            interview.job_description,
            interview.language or "fr",
        )
        gpt_messages = [{"role": "system", "content": system_prompt}]
        for msg in messages:
            gpt_messages.append({"role": msg.role, "content": msg.content})
        gpt_messages.append({"role": "user", "content": user_message.strip()})

        # Forcer la clôture si on atteint la limite
        if assistant_count >= MAX_QUESTIONS - 1:
            gpt_messages.append({
                "role": "system",
                "content": "C'est la dernière question. Remercie le candidat et clôture l'entretien. question_type=closing, question_number=15."
            })

        # Appeler GPT en streaming
        stream = await client.chat.completions.create(
            model="gpt-4o-mini",
            messages=gpt_messages,
            temperature=0.7,
            max_tokens=800,
            stream=True,
        )

        accumulated = ""
        streaming_text = True

        async for chunk in stream:
            delta = chunk.choices[0].delta
            if delta.content:
                accumulated += delta.content

                if streaming_text:
                    # Vérifier si le délimiteur est arrivé
                    if FEEDBACK_DELIMITER in accumulated:
                        parts = accumulated.split(FEEDBACK_DELIMITER, 1)
                        # Envoyer le texte restant avant le délimiteur
                        text_part = parts[0].rstrip()
                        if text_part:
                            # Le texte a peut-être déjà été partiellement envoyé
                            pass
                        streaming_text = False
                    else:
                        # Streamer le texte (mais garder un buffer pour ne pas couper le délimiteur)
                        safe_end = len(accumulated) - len(FEEDBACK_DELIMITER)
                        if safe_end > 0:
                            to_send = accumulated[:safe_end]
                            if to_send:
                                yield ("stream", to_send)
                                accumulated = accumulated[safe_end:]

        # Traitement final
        if FEEDBACK_DELIMITER in accumulated:
            parts = accumulated.split(FEEDBACK_DELIMITER, 1)
            message_text = parts[0].rstrip()
            # Envoyer le texte restant
            if message_text:
                yield ("stream", message_text)
            yield ("stream_end", None)

            # Parser le feedback JSON
            feedback_raw = parts[1].strip()
            try:
                feedback_data = json.loads(feedback_raw)
            except json.JSONDecodeError:
                feedback_data = {"feedback": None, "question_type": "unknown", "question_number": assistant_count + 1}

            # Reconstruire le message complet pour la sauvegarde
            full_message = parts[0].rstrip()
        else:
            # Pas de délimiteur trouvé — envoyer tout le texte
            yield ("stream", accumulated)
            yield ("stream_end", None)
            full_message = accumulated
            feedback_data = {"feedback": None, "question_type": "unknown", "question_number": assistant_count + 1}

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
        question_number = feedback_data.get("question_number", assistant_count + 1)
        is_last = question_type == "closing" or question_number >= MAX_QUESTIONS

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

    # ─── Terminer en avance ──────────────────────────────────────

    async def end_session_early(self, session_id: str, user_id: str) -> dict:
        """Force la fin de l'entretien. Envoie 'Avez-vous des questions ?' puis clôture."""
        interview = await self.repo.get_session_by_id(session_id, user_id)
        if not interview:
            raise HTTPException(status_code=404, detail="Session not found")
        if interview.status != "in_progress":
            raise HTTPException(status_code=400, detail="Session already completed")

        messages = await self.repo.get_messages_by_session(session_id)
        system_prompt = build_interview_prompt(
            interview.job_title, interview.company_name,
            interview.job_description, interview.language or "fr",
        )

        gpt_messages = [{"role": "system", "content": system_prompt}]
        for msg in messages:
            gpt_messages.append({"role": msg.role, "content": msg.content})
        gpt_messages.append({
            "role": "system",
            "content": "Le candidat souhaite terminer l'entretien. Pose-lui 'Avez-vous des questions sur le poste ou l'entreprise ?' puis clôture. question_type=candidate_questions puis closing."
        })

        response = await client.chat.completions.create(
            model="gpt-4o-mini",
            messages=gpt_messages,
            temperature=0.7,
            max_tokens=800,
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

    # ─── Bilan ───────────────────────────────────────────────────

    async def _generate_summary(self, session_id: str, user_id: str, language: str) -> dict:
        messages = await self.repo.get_messages_by_session(session_id)

        # Construire l'historique complet
        history = "\n\n".join(
            f"{'Recruteur' if m.role == 'assistant' else 'Candidat'}: {m.content}"
            for m in messages
        )

        summary_prompt = build_summary_prompt(language)

        response = await client.chat.completions.create(
            model="gpt-4o",
            messages=[
                {"role": "system", "content": summary_prompt},
                {"role": "user", "content": f"Voici la transcription de l'entretien :\n\n{history}"},
            ],
            temperature=0.3,
            max_tokens=2000,
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

    # ─── CRUD ────────────────────────────────────────────────────

    async def get_session(self, session_id: str, user_id: str):
        session = await self.repo.get_session_by_id(session_id, user_id)
        if not session:
            raise HTTPException(status_code=404, detail="Session not found")
        return session

    async def get_history(self, user_id: str):
        return await self.repo.get_sessions_by_user(user_id)

    async def delete_session(self, session_id: str, user_id: str):
        deleted = await self.repo.delete_session(session_id, user_id)
        if not deleted:
            raise HTTPException(status_code=404, detail="Session not found")
        await self.session.commit()

    async def delete_all(self, user_id: str) -> int:
        count = await self.repo.delete_all_by_user(user_id)
        await self.session.commit()
        return count


def _parse_response(raw: str) -> tuple[str, dict | None]:
    """Parse la réponse GPT en séparant le texte et le feedback JSON."""
    if FEEDBACK_DELIMITER in raw:
        parts = raw.split(FEEDBACK_DELIMITER, 1)
        message_text = parts[0].rstrip()
        try:
            feedback_data = json.loads(parts[1].strip())
        except json.JSONDecodeError:
            feedback_data = None
        return message_text, feedback_data
    return raw, None
