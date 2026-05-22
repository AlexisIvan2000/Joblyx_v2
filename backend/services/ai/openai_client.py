import json
import logging
from typing import Any

from openai import AsyncOpenAI

from core.config import OPENAI_API_KEY, OPENAI_MODEL_PRIMARY
from services.ai.usage_tracker import track_usage

logger = logging.getLogger(__name__)

client = AsyncOpenAI(api_key=OPENAI_API_KEY)


# Wrappers génériques, à utiliser depuis tous les services qui appellent OpenAI

async def tracked_completion(
    *,
    user_id: str | None,
    feature: str,
    model: str,
    messages: list[dict],
    **openai_kwargs: Any,
):
    """Wrapper non-stream qui capture l'usage après la réponse et le persiste."""
    response = await client.chat.completions.create(
        model=model,
        messages=messages,
        **openai_kwargs,
    )
    # Best effort, ne bloque pas le retour si le tracking foire
    await track_usage(user_id=user_id, feature=feature, model=model, usage=response.usage)
    return response


async def tracked_completion_stream(
    *,
    user_id: str | None,
    feature: str,
    model: str,
    messages: list[dict],
    **openai_kwargs: Any,
):
    """Wrapper stream qui ajoute stream_options={'include_usage': True} et capte le dernier chunk.

    Retourne un async generator de chunks. Le chunk usage (dernier de la séquence) est consommé
    en interne, pas yieldé, pour rester compatible avec les appels existants.
    """
    # Force l'inclusion du usage dans le dernier chunk du stream
    stream_options = openai_kwargs.pop("stream_options", {}) or {}
    stream_options["include_usage"] = True

    stream = await client.chat.completions.create(
        model=model,
        messages=messages,
        stream=True,
        stream_options=stream_options,
        **openai_kwargs,
    )

    last_usage = None
    async for chunk in stream:
        # Le chunk usage n'a pas de choices (ou un tableau vide), on l'intercepte et on continue
        usage_attr = getattr(chunk, "usage", None)
        if usage_attr is not None:
            last_usage = usage_attr
        if not chunk.choices:
            # Chunk usage uniquement, ne pas le yielder vers l'appelant
            continue
        yield chunk

    if last_usage is not None:
        await track_usage(user_id=user_id, feature=feature, model=model, usage=last_usage)


# Helpers spécifiques roadmap, gardent l'API existante mais demandent maintenant user_id

async def generate_roadmap(system_prompt: str, user_prompt: str, *, user_id: str | None = None) -> dict:
    response = await tracked_completion(
        user_id=user_id,
        feature="roadmap",
        model=OPENAI_MODEL_PRIMARY,
        messages=[
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_prompt},
        ],
        temperature=0.7,
        response_format={"type": "json_object"},
    )
    content = response.choices[0].message.content
    return json.loads(content)


async def generate_roadmap_stream(system_prompt: str, user_prompt: str, *, user_id: str | None = None):
    """Streaming, yields (event, data) tuples.

    Events:
      ("chunk", partial_text), ("done", parsed_dict), ("error", error_msg)
    """
    accumulated = ""
    async for chunk in tracked_completion_stream(
        user_id=user_id,
        feature="roadmap",
        model=OPENAI_MODEL_PRIMARY,
        messages=[
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_prompt},
        ],
        temperature=0.7,
        response_format={"type": "json_object"},
    ):
        delta = chunk.choices[0].delta
        if delta.content:
            accumulated += delta.content
            yield ("chunk", delta.content)

    try:
        parsed = json.loads(accumulated)
        yield ("done", parsed)
    except json.JSONDecodeError as e:
        yield ("error", f"Invalid JSON from GPT: {e}")
