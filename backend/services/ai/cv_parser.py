import json
import fitz  # PyMuPDF
from pathlib import Path
from services.ai.openai_client import client

# Charger le référentiel de skills une seule fois
_SKILLS_PATH = Path(__file__).resolve().parent.parent.parent / "models" / "data" / "skills.json"

def _load_skills_reference() -> dict:
    """Charge skills.json et retourne {catégorie: [noms de skills]}."""
    with open(_SKILLS_PATH, encoding="utf-8") as f:
        data = json.load(f)
    it = data.get("IT", {})
    return {cat: [s["name"] for s in skills] for cat, skills in it.items()}


_SKILLS_REF = _load_skills_reference()
_CATEGORIES = list(_SKILLS_REF.keys())

# Index inversé nom/variant → (skill_name, category) pour la normalisation post-GPT
_SKILL_INDEX: dict[str, tuple[str, str]] = {}
with open(_SKILLS_PATH, encoding="utf-8") as _f:
    _raw = json.load(_f)
for _cat, _skills_list in _raw.get("IT", {}).items():
    for _skill in _skills_list:
        _name = _skill["name"]
        _SKILL_INDEX[_name.lower()] = (_name, _cat)
        for _v in _skill.get("variants", []):
            if _v:
                _SKILL_INDEX[_v.lower()] = (_name, _cat)

# Prompt système pré-calculé (compact : une ligne par catégorie, format CSV)
_CATEGORIES_COMPACT = "|".join(
    f"{cat}:{','.join(skills)}" for cat, skills in _SKILLS_REF.items()
)
_SYSTEM_PROMPT = (
    "Extract technical skills from this CV. Return JSON: "
    '{"skills":[{"skill_name":"X","category":"cat","proficiency":"beginner|intermediate|advanced"}]}. '
    "Rules: only skills from the reference below, normalize names (k8s→Kubernetes, JS→JavaScript), "
    "estimate proficiency from context, max 20 skills.\n"
    f"Reference (category:skill1,skill2|...):\n{_CATEGORIES_COMPACT}"
)


def extract_text_from_pdf(pdf_bytes: bytes) -> str:
    """Extrait le texte d'un PDF via PyMuPDF."""
    doc = fitz.open(stream=pdf_bytes, filetype="pdf")
    text = ""
    for page in doc:
        text += page.get_text()
    doc.close()
    return text.strip()


def _validate_skills(raw_skills: list[dict]) -> list[dict]:
    """Normalise et valide les skills contre le référentiel."""
    validated = []
    seen = set()
    for s in raw_skills:
        name = s.get("skill_name", "").strip()
        category = s.get("category", "").strip()
        proficiency = s.get("proficiency", "intermediate").strip()

        if proficiency not in ("beginner", "intermediate", "advanced"):
            proficiency = "intermediate"

        # Chercher dans l'index (matching exact)
        lookup = _SKILL_INDEX.get(name.lower())
        if lookup:
            name, category = lookup
        elif category not in _CATEGORIES:
            continue

        # Vérifier que le skill existe dans sa catégorie
        if category in _SKILLS_REF and name in _SKILLS_REF[category]:
            if name not in seen:
                seen.add(name)
                validated.append({
                    "skill_name": name,
                    "category": category,
                    "proficiency": proficiency,
                })

    return validated


async def extract_skills_from_cv(pdf_bytes: bytes) -> list[dict]:
    """Parse le CV, extrait les skills via GPT, et les normalise."""
    cv_text = extract_text_from_pdf(pdf_bytes)
    if not cv_text:
        return []

    if len(cv_text) > 9000:
        cv_text = cv_text[:9000]

    response = await client.chat.completions.create(
        model="gpt-4o-mini",
        messages=[
            {"role": "system", "content": _SYSTEM_PROMPT},
            {"role": "user", "content": cv_text},
        ],
        temperature=0.2,
        max_tokens=1000,
        response_format={"type": "json_object"},
    )

    content = response.choices[0].message.content
    result = json.loads(content)
    return _validate_skills(result.get("skills", []))


async def extract_skills_from_cv_stream(pdf_bytes: bytes):
    """Version streaming — yield (event_type, data) tuples.

    Events:
      ("chunk", partial_text)  — token brut du stream GPT
      ("done", validated_skills)  — liste finale de skills validées
      ("error", error_msg)  — en cas d'erreur
    """
    cv_text = extract_text_from_pdf(pdf_bytes)
    if not cv_text:
        yield ("done", [])
        return

    if len(cv_text) > 9000:
        cv_text = cv_text[:9000]

    stream = await client.chat.completions.create(
        model="gpt-4o-mini",
        messages=[
            {"role": "system", "content": _SYSTEM_PROMPT},
            {"role": "user", "content": cv_text},
        ],
        temperature=0.2,
        max_tokens=1000,
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
        validated = _validate_skills(parsed.get("skills", []))
        yield ("done", validated)
    except json.JSONDecodeError as e:
        yield ("error", f"Invalid JSON from GPT: {e}")
