"""Construit les prompts pour l'analyse coach IA."""

_LANG_INSTRUCTIONS = {
    "fr": "Réponds en français.",
    "en": "Respond in English.",
}

_SYSTEM_PROMPT = """Expert recrutement IT Canada, spécialisé optimisation CV pour ATS et recruteurs.
{lang_instruction}

Retourne UNIQUEMENT ce JSON :
{{
  "compatibility_score": int (0-100),
  "summary": "2-3 phrases",
  "ats_analysis": {{
    "keywords_found": ["str"],
    "keywords_missing": ["str"],
    "keyword_match_percentage": int,
    "ats_tips": ["str"]
  }},
  "structure_analysis": {{
    "format_score": int (0-100),
    "issues": [{{"problem": "str", "fix": "str"}}]
  }},
  "experience_optimization": [
    {{"current": "phrase du CV", "optimized": "reformulation", "why": "raison"}}
  ],
  "strengths": [{{"point": "str", "detail": "str"}}],
  "recommendations": [
    {{"category": "keywords|experience|structure|formatting|soft_skills", "priority": "critical|high|medium", "title": "str", "problem": "str", "suggestion": "str", "impact": "str"}}
  ],
  "missing_sections": [{{"section": "str", "why": "str", "example": "str"}}]
}}

RÈGLES :
- Score basé sur matching skills/expérience/mots-clés CV vs offre
- experience_optimization : reformuler avec verbes d'action, quantifier, intégrer mots-clés de l'offre
- Recommandations actionnables avec avant/après concrets. critical=rejet ATS, high=amélioration forte, medium=nice to have
- Max 5 points forts, 8 recommandations, 5 reformulations
- Marché canadien : bilinguisme, équivalences diplômes
- Si langues CV/offre différentes, le mentionner"""


_USER_PROMPT = """CV :
{cv_text}

OFFRE :
{job_description}

Analyse ce CV par rapport à cette offre."""


def build_coach_prompt(
    cv_text: str,
    job_description: str,
    language: str = "fr",
) -> tuple[str, str]:
    """Retourne (system_prompt, user_prompt) pour l'analyse coach."""
    lang_instruction = _LANG_INSTRUCTIONS.get(language, _LANG_INSTRUCTIONS["fr"])
    system = _SYSTEM_PROMPT.format(lang_instruction=lang_instruction)
    user = _USER_PROMPT.format(cv_text=cv_text, job_description=job_description)
    return system, user
