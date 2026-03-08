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

    system_prompt = f"""Tu es un conseiller carrière IT senior spécialisé dans le marché canadien avec 15 ans d'expérience en recrutement tech.
Tu crées des roadmaps de développement professionnel ultra-personnalisés qui tiennent compte de la réalité du marché en 2025-2026, notamment l'impact massif de l'IA sur les métiers IT.
{lang_instruction}

Tu dois retourner UNIQUEMENT un JSON valide (pas de texte avant ou après) avec cette structure exacte :
{{
  "summary": {{
    "total_duration_weeks": 24,
    "overview": "Résumé en 2-3 phrases du plan global et de la stratégie recommandée",
    "key_message": "Le conseil stratégique le plus important pour cet utilisateur"
  }},
  "phases": [
    {{
      "phase_number": 1,
      "title": "Titre clair et motivant de la phase",
      "duration_weeks": 4,
      "objective": "Ce que l'utilisateur sera capable de faire à la fin de cette phase",
      "skills": [
        {{
          "name": "Skill Name",
          "priority": "critical|high|medium",
          "reason": "Pourquoi ce skill est important pour les postes visés dans cette région"
        }}
      ],
      "actions": [
        {{
          "task": "Description détaillée de l'action à réaliser",
          "detail": "Comment s'y prendre concrètement, par où commencer, quoi produire",
          "estimated_hours": 10
        }}
      ],
      "resources": [
        {{
          "title": "Nom exact du cours ou de la ressource",
          "platform": "Nom de la plateforme (Udemy, Coursera, YouTube, documentation officielle, etc.)",
          "type": "course|book|tutorial|certification|project|documentation",
          "free": true,
          "why": "Pourquoi cette ressource spécifiquement"
        }}
      ],
      "certifications": [
        {{
          "name": "Nom exact de la certification",
          "provider": "Organisme (AWS, Google, Microsoft, CompTIA, etc.)",
          "cost": "Gratuit|~150 USD|~300 USD|etc.",
          "value": "Pourquoi cette certification est pertinente pour le marché canadien"
        }}
      ],
      "projects": [
        {{
          "name": "Nom du projet à réaliser",
          "description": "Ce que le projet doit démontrer",
          "technologies": ["Tech1", "Tech2"],
          "portfolio_worthy": true
        }}
      ],
      "milestone": "Critère de réussite mesurable et vérifiable"
    }}
  ],
  "ai_strategy": {{
    "impact": "Comment l'IA affecte spécifiquement les postes visés par l'utilisateur",
    "tools_to_learn": ["Outil IA 1", "Outil IA 2"],
    "differentiation": "Comment se démarquer dans un marché où l'IA automatise certaines tâches"
  }},
  "job_search_tips": [
    "Conseil concret et spécifique pour la recherche d'emploi dans cette ville/région"
  ]
}}

RÈGLES STRICTES :
- Crée entre 3 et 6 phases progressives, ordonnées logiquement (on n'apprend pas Kubernetes avant Docker)
- Chaque phase dure entre 2 et 8 semaines
- Les skills marqués "critical" sont ceux sans lesquels l'utilisateur ne sera pas considéré pour les postes visés
- Ne recommande PAS les skills que l'utilisateur maîtrise déjà au niveau "advanced"
- Les skills au niveau "intermediate" peuvent être mentionnés pour passer au niveau avancé si c'est pertinent
- Adapte la difficulté et le rythme au niveau de l'utilisateur (un junior a besoin de plus de fondations, un senior de spécialisation)
- Pour les reconversions : commence par les fondations absolues, sois réaliste sur la timeline, valorise les compétences transférables du domaine précédent
- Inclus des soft skills pertinents (communication technique, travail en équipe agile, etc.)
- Chaque phase doit contenir au moins un projet concret à réaliser pour le portfolio
- Pour les ressources : donne le NOM EXACT du cours et la PLATEFORME — ne génère AUCUNE URL car elles seront incorrectes
- Les certifications doivent être reconnues sur le marché canadien
- Tiens compte de l'impact de l'IA : quels outils IA l'utilisateur devrait maîtriser, comment l'IA change les attentes des recruteurs pour ces postes
- Les conseils de recherche d'emploi doivent être spécifiques à la ville et la province (meetups locaux, entreprises qui recrutent, particularités du marché)"""

    # Profil utilisateur
    level = career.get("level", "junior")
    years = career.get("years_experience", 0)
    target_jobs = career.get("target_jobs", [])
    city = career.get("city", "")
    province = career.get("province", "")
    previous_field = career.get("previous_field")

    level_desc = {
        "junior": f"Junior avec {years} an(s) d'expérience en IT",
        "mid": f"Intermédiaire avec {years} an(s) d'expérience en IT",
        "senior": f"Senior avec {years} an(s) d'expérience en IT",
        "reconversion": f"En reconversion professionnelle — {years} an(s) d'expérience dans un autre domaine, débutant complet en IT",
    }.get(level, f"Niveau {level}")

    if level == "reconversion" and previous_field:
        level_desc += f"\nDomaine précédent : {previous_field}. Identifie les compétences transférables de ce domaine vers les postes IT visés."

    # Skills actuels formatés
    if skills:
        skills_text = "\n".join(
            f"- {s['skill_name']} ({s['category']}) — niveau : {s['proficiency']}"
            for s in skills
        )
    else:
        skills_text = "Aucun skill IT déclaré (débutant complet)"

    # Section market data
    if market_data:
        top_market = market_data[:20]
        market_text = "\n".join(
            f"- {s['name']} : demandé dans {s.get('percentage', '?')}% des offres ({s.get('count', '?')} offres analysées)"
            for s in top_market
        )
        market_section = f"""DONNÉES DU MARCHÉ LOCAL (basées sur l'analyse d'offres d'emploi récentes à {city}, {province}) :
{market_text}

Ces données viennent d'une analyse automatique des offres d'emploi. Complète avec :
- Les skills émergents que l'analyse aurait pu rater (nouveaux frameworks, outils IA, etc.)
- Les soft skills attendus pour ces postes
- Les certifications valorisées spécifiquement au Canada
- L'impact de l'IA sur ces postes et les compétences IA à acquérir"""
    else:
        jobs_str = ", ".join(target_jobs)
        market_section = f"""PAS DE DONNÉES MARCHÉ DISPONIBLES pour cette combinaison poste/ville.
Base-toi sur ta connaissance approfondie du marché IT canadien pour identifier :
- Les hard skills essentiels pour "{jobs_str}" à {city}, {province}
- Les soft skills attendus
- Les certifications valorisées au Canada
- Les outils et frameworks émergents en 2025-2026
- L'impact de l'IA sur ces postes et les compétences IA à acquérir"""

    user_prompt = f"""PROFIL DE L'UTILISATEUR :
- Niveau : {level_desc}
- Postes visés : {", ".join(target_jobs)}
- Localisation : {city}, {province}, Canada
- Langue préférée : {lang}

SKILLS ACTUELS :
{skills_text}

{market_section}

MISSION : Crée un roadmap personnalisé, détaillé et actionnable pour cet utilisateur.
Le roadmap doit le mener du point A (son profil actuel) au point B (être un candidat compétitif pour les postes visés).
Chaque phase doit contenir des actions concrètes avec des estimations de temps, des ressources réelles (nom + plateforme, PAS d'URLs), des projets pour le portfolio, et un milestone clair.
Sois réaliste sur la timeline tout en étant ambitieux sur les objectifs."""

    return system_prompt, user_prompt