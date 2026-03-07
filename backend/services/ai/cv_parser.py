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
# Construire un index inversé nom/variant → (skill_name, category)
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


def extract_text_from_pdf(pdf_bytes: bytes) -> str:
    """Extrait le texte d'un PDF via PyMuPDF."""
    doc = fitz.open(stream=pdf_bytes, filetype="pdf")
    text = ""
    for page in doc:
        text += page.get_text()
    doc.close()
    return text.strip()


async def extract_skills_from_cv(pdf_bytes: bytes) -> list[dict]:
    """Parse le CV, extrait les skills via GPT, et les normalise."""
    cv_text = extract_text_from_pdf(pdf_bytes)
    if not cv_text:
        return []

    # Tronquer si trop long (limite ~12k chars pour garder de la marge)
    if len(cv_text) > 12000:
        cv_text = cv_text[:12000]

    # Construire le prompt avec le référentiel
    categories_with_skills = "\n".join(
        f"- {cat}: {', '.join(skills[:15])}{'...' if len(skills) > 15 else ''}"
        for cat, skills in _SKILLS_REF.items()
    )

    system_prompt = f"""Tu es un expert en recrutement IT. Extrais les compétences techniques de ce CV.

Règles :
1. Retourne UNIQUEMENT des skills présents dans le référentiel ci-dessous.
2. Normalise les noms (ex: "k8s" → "Kubernetes", "JS" → "JavaScript", "React.js" → "React").
3. Estime le niveau (beginner/intermediate/advanced) selon le contexte du CV (années d'expérience, projets, rôle).
4. Catégorise chaque skill selon les catégories du référentiel.
5. Maximum 20 skills, priorise les plus pertinents.

Catégories et exemples de skills du référentiel :
{categories_with_skills}

Retourne un JSON avec cette structure exacte :
{{"skills": [{{"skill_name": "Python", "category": "programming_languages", "proficiency": "advanced"}}]}}"""

    response = await client.chat.completions.create(
        model="gpt-4o-mini",
        messages=[
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": f"Voici le CV :\n\n{cv_text}"},
        ],
        temperature=0.3,
        response_format={"type": "json_object"},
    )

    content = response.choices[0].message.content
    result = json.loads(content)
    raw_skills = result.get("skills", [])

    # Normaliser et valider contre le référentiel
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
            continue  # Catégorie inconnue et skill non trouvé

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
