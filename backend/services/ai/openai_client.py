import json
from openai import AsyncOpenAI
from core.config import OPENAI_API_KEY


client = AsyncOpenAI(api_key=OPENAI_API_KEY)


async def generate_roadmap(system_prompt: str, user_prompt: str) -> dict:
    # Appel GPT-4o et parsing du JSON retourné
    response = await client.chat.completions.create(
        model="gpt-4o-mini",
        messages=[
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_prompt},
        ],
        temperature=0.7,
        response_format={"type": "json_object"},
    )

    content = response.choices[0].message.content
    return json.loads(content)
