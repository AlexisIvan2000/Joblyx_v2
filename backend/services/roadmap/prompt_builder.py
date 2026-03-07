def build_roadmap_prompt(
    career: dict,
    skills: list[dict],
    market_data: list[dict] | None,
) -> tuple[str, str]:
    """Construit le system prompt et le user prompt pour GPT-4o.

    Retourne (system_prompt, user_prompt).
    """
    lang = career.get("language", "fr")
    lang_instruction = "Réponds entièrement en français." if lang == "fr" else (
        "Reply entirely in English." if lang == "en" else
        "Reply in both French and English (bilingual)."
    )

    system_prompt = f"""Tu es un conseiller carrière IT expert du marché canadien.
Tu crées des roadmaps de développement professionnel personnalisés.
{lang_instruction}

Tu dois retourner un JSON valide avec cette structure exacte :
{{
  "phases": [
    {{
      "title": "Titre de la phase",
      "duration_weeks": 4,
      "skills": [
        {{"name": "Skill Name", "priority": "high|medium|low"}}
      ],
      "actions": ["Action concrète 1", "Action concrète 2"],
      "resources": [
        {{"title": "Nom", "url": "https://...", "type": "course|book|tutorial|certification|project", "free": true}}
      ],
      "certifications": ["Certification recommandée"],
      "milestone": "Critère de réussite mesurable pour cette phase"
    }}
  ]
}}

Règles :
- Crée entre 3 et 6 phases progressives
- Chaque phase dure entre 2 et 8 semaines
- Inclus des soft skills, certifications, et outils émergents — pas seulement des hard skills techniques
- Les ressources doivent avoir des URLs réelles et fonctionnelles (Udemy, Coursera, YouTube, docs officielles, etc.)
- Les milestones doivent être mesurables et concrets (projet à réaliser, certification à obtenir, etc.)
- Ne recommande PAS les skills que l'utilisateur maîtrise déjà au niveau "advanced"
- Adapte la difficulté et le rythme au niveau de l'utilisateur"""

    # Profil utilisateur
    level = career.get("level", "junior")
    years = career.get("years_experience", 0)
    target_jobs = career.get("target_jobs", [])
    city = career.get("city", "")
    province = career.get("province", "")
    previous_field = career.get("previous_field")

    level_desc = {
        "junior": f"Junior avec {years} an(s) d'expérience",
        "mid": f"Intermédiaire avec {years} an(s) d'expérience",
        "senior": f"Senior avec {years} an(s) d'expérience",
        "reconversion": f"En reconversion professionnelle ({years} an(s) d'expérience dans un autre domaine)",
    }.get(level, f"Niveau {level}")

    if level == "reconversion" and previous_field:
        level_desc += f" — domaine précédent : {previous_field}"

    # Skills actuels formatés
    skills_text = "\n".join(
        f"- {s['skill_name']} ({s['category']}) — niveau : {s['proficiency']}"
        for s in skills
    )

    # Section market data
    if market_data:
        top_market = market_data[:20]
        market_text = "\n".join(
            f"- {s['name']} : demandé dans {s.get('percentage', '?')}% des offres ({s.get('count', '?')} offres)"
            for s in top_market
        )
        market_section = f"""Voici les skills les plus demandés selon les offres d'emploi récentes dans cette région :
{market_text}

Complète cette liste avec d'autres skills pertinents que tu connais pour ce poste et cette région (soft skills, certifications spécifiques, outils émergents que l'analyse automatique aurait pu rater)."""
    else:
        jobs_str = ", ".join(target_jobs)
        market_section = f"""Génère la liste des skills essentiels pour "{jobs_str}" à {city}, {province} en te basant sur ta connaissance du marché IT canadien.
Inclus les hard skills, soft skills, certifications pertinentes et outils émergents."""

    user_prompt = f"""Profil de l'utilisateur :
- Niveau : {level_desc}
- Postes visés : {", ".join(target_jobs)}
- Localisation : {city}, {province}, Canada

Skills actuels :
{skills_text}

{market_section}

Crée un roadmap personnalisé avec des phases progressives pour atteindre les postes visés.
Tiens compte des skills déjà maîtrisés pour ne pas les répéter et concentre-toi sur les lacunes à combler."""

    return system_prompt, user_prompt
