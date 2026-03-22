import json
from openai import AsyncOpenAI
from core.config import OPENAI_API_KEY, OPENAI_MODEL_PRIMARY


client = AsyncOpenAI(api_key=OPENAI_API_KEY)

# Version classique — retourne la roadmap complète à la fin
async def generate_roadmap(system_prompt: str, user_prompt: str) -> dict:
    
    response = await client.chat.completions.create(
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

# Version streaming — yields (event, data) tuples
async def generate_roadmap_stream(system_prompt: str, user_prompt: str):
    """Streaming version — yields (event, data) tuples.

    Events:
      ("chunk", partial_text)  — raw token chunk
      ("done", parsed_dict)   — final parsed JSON
      ("error", error_msg)    — on failure
    """
    stream = await client.chat.completions.create(
        model=OPENAI_MODEL_PRIMARY,
        messages=[
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_prompt},
        ],
        temperature=0.7,
        response_format={"type": "json_object"},
        stream=True,
    )

    accumulated = ""
    async for chunk in stream:
        delta = chunk.choices[0].delta
        if delta.content:
            accumulated += delta.content
            yield ("chunk", delta.content)

    try:
        parsed = json.loads(accumulated)
        yield ("done", parsed)
    except json.JSONDecodeError as e:
        yield ("error", f"Invalid JSON from GPT: {e}")
