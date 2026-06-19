import json

from core.config import OPENAI_MODEL_FAST
from services.ai.openai_client import tracked_completion_stream

FEEDBACK_DELIMITER = "<<<FEEDBACK_JSON>>>"


def default_feedback(question_number: int) -> dict:
    return {"feedback": None, "question_type": "unknown", "question_number": question_number, "counts_as_question": True}


def parse_response(raw: str) -> tuple[str, dict | None]:
    if FEEDBACK_DELIMITER in raw:
        parts = raw.split(FEEDBACK_DELIMITER, 1)
        message_text = parts[0].rstrip()
        try:
            feedback_data = json.loads(parts[1].strip())
        except json.JSONDecodeError:
            feedback_data = None
        return message_text, feedback_data
    return raw, None


async def stream_assistant_reply(user_id: str, gpt_messages: list, fallback_question_number: int):
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
                if FEEDBACK_DELIMITER in full_text:
                    remaining = accumulated.split(FEEDBACK_DELIMITER, 1)[0]
                    if remaining:
                        yield ("stream", remaining)
                    streaming_text = False
                else:
                    safe_end = len(accumulated) - len(FEEDBACK_DELIMITER)
                    if safe_end > 0:
                        to_send = accumulated[:safe_end]
                        if to_send:
                            yield ("stream", to_send)
                            accumulated = accumulated[safe_end:]

    if FEEDBACK_DELIMITER in full_text:
        parts = full_text.split(FEEDBACK_DELIMITER, 1)
        full_message = parts[0].rstrip()

        if streaming_text and accumulated:
            remaining = accumulated.split(FEEDBACK_DELIMITER, 1)[0]
            if remaining:
                yield ("stream", remaining)

        yield ("stream_end", None)

        try:
            feedback_data = json.loads(parts[1].strip())
        except json.JSONDecodeError:
            feedback_data = default_feedback(fallback_question_number)
    else:
        if accumulated:
            yield ("stream", accumulated)
        yield ("stream_end", None)
        full_message = full_text.rstrip()
        feedback_data = default_feedback(fallback_question_number)

    yield ("reply", (full_message, feedback_data))
