def build_roadmap_prompt(
    career: dict,
    skills: list[dict],
    market_data: list[dict] | None,
    completed_data: dict | None = None,
) -> tuple[str, str]:
    """Construit (system_prompt, user_prompt) pour GPT-4o."""
    lang = career.get("language", "fr")
    lang_instruction = "Réponds en français." if lang == "fr" else (
        "Reply in English." if lang == "en" else
        "Reply bilingually (French + English)."
    )

    system_prompt = f"""Conseiller carrière IT senior, marché canadien, expert recrutement tech.
{lang_instruction}

Retourne UNIQUEMENT ce JSON :
{{
  "summary": {{"total_duration_weeks": int, "overview": "2-3 phrases", "key_message": "conseil stratégique principal"}},
  "phases": [
    {{
      "phase_number": int,
      "title": "str",
      "duration_weeks": int (2-8),
      "objective": "str",
      "skills": [{{"name": "str", "priority": "critical|high|medium", "reason": "str"}}],
      "actions": [{{"task": "str", "detail": "str", "estimated_hours": int}}],
      "resources": [{{"title": "nom exact", "platform": "str", "type": "course|book|tutorial|certification|project|documentation", "free": bool, "why": "str"}}],
      "certifications": [{{"name": "str", "provider": "str", "cost": "str", "value": "str"}}],
      "projects": [{{"name": "str", "description": "str", "technologies": ["str"], "portfolio_worthy": bool}}],
      "milestone": "critère mesurable"
    }}
  ],
  "ai_strategy": {{"impact": "str", "tools_to_learn": ["str"], "differentiation": "str"}},
  "job_search_tips": ["str"]
}}

RÈGLES :
- 3-6 phases progressives, ordonnées logiquement
- Ne pas recommander les skills déjà "advanced". Skills "intermediate" peuvent passer en avancé si pertinent
- Adapter difficulté au niveau (junior=fondations, senior=spécialisation, reconversion=bases+compétences transférables)
- Au moins 1 projet portfolio par phase
- Ressources : NOM EXACT + PLATEFORME, jamais d'URLs
- Certifications reconnues au Canada
- Inclure impact IA et outils IA pertinents
- Conseils recherche d'emploi spécifiques à la ville/province"""

    # Profil utilisateur
    level = career.get("level", "junior")
    years = career.get("years_experience", 0)
    target_jobs = career.get("target_jobs", [])
    city = career.get("city", "")
    province = career.get("province", "")
    previous_field = career.get("previous_field")

    level_desc = {
        "junior": f"Junior, {years} an(s) IT",
        "mid": f"Intermédiaire, {years} an(s) IT",
        "senior": f"Senior, {years} an(s) IT",
        "reconversion": f"Reconversion, {years} an(s) autre domaine, débutant IT",
    }.get(level, f"Niveau {level}")

    if level == "reconversion" and previous_field:
        level_desc += f" (ex-{previous_field}, identifier compétences transférables)"

    # Skills actuels
    if skills:
        skills_text = "\n".join(
            f"- {s['skill_name']} ({s['category']}) — {s['proficiency']}"
            for s in skills
        )
    else:
        skills_text = "Aucun skill IT (débutant complet)"

    # Market data
    if market_data:
        top_market = market_data[:15]
        market_text = "\n".join(
            f"- {s['name']} : {s.get('percentage', '?')}% des offres"
            for s in top_market
        )
        market_section = f"MARCHÉ LOCAL ({city}, {province}) :\n{market_text}"
    else:
        market_section = f"Pas de données marché. Utilise ta connaissance du marché IT à {city}, {province}."

    # Progression existante
    progress_section = ""
    if completed_data:
        parts = []
        if completed_data.get("completed_phases"):
            parts.append("Phases faites : " + ", ".join(completed_data["completed_phases"]))
        if completed_data.get("acquired_skills"):
            parts.append("Skills acquis : " + ", ".join(completed_data["acquired_skills"]))
        if parts:
            progress_section = "PROGRESSION :\n" + "\n".join(f"- {p}" for p in parts) + "\nAdapter le roadmap en continuant depuis cette progression."

    user_prompt = f"""PROFIL : {level_desc}
Postes visés : {", ".join(target_jobs)}
Localisation : {city}, {province}, Canada

SKILLS ACTUELS :
{skills_text}

{market_section}
{progress_section}
Crée un roadmap personnalisé et actionnable pour mener ce candidat aux postes visés."""

    return system_prompt, user_prompt
