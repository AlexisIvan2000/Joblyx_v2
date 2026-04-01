"""Validation des titres de poste — restreint aux métiers IT."""

import re
from fastapi import HTTPException, status

# Caractères autorisés : lettres (accents inclus), chiffres, espaces, tirets, points, slashes, parenthèses
_ALLOWED_PATTERN = re.compile(r"^[\w\s\-./()&+,#àâäéèêëïîôùûüçÀÂÄÉÈÊËÏÎÔÙÛÜÇ]+$", re.UNICODE)

# Mots-clés IT — au moins un doit être présent dans le titre (insensible à la casse)
_IT_KEYWORDS = {
    # Développement
    "developer", "développeur", "développeuse", "dev", "programmer", "programmeur",
    "software", "logiciel", "fullstack", "full-stack", "full stack",
    "frontend", "front-end", "front end", "backend", "back-end", "back end",
    "mobile", "web", "api", "microservices",
    # Engineering
    "engineer", "ingénieur", "ingénieure", "engineering",
    "sre", "site reliability", "platform",
    # Data
    "data", "database", "données", "analytics", "analyst", "analyste",
    "machine learning", "ml", "deep learning", "ai", "ia",
    "data scientist", "data engineer", "data analyst",
    "bi", "business intelligence", "etl", "pipeline",
    # Cloud & Infra
    "cloud", "aws", "azure", "gcp", "devops", "devsecops",
    "infrastructure", "infra", "sysadmin", "système", "systems",
    "network", "réseau", "linux", "kubernetes", "docker", "terraform",
    # Sécurité
    "security", "sécurité", "cybersecurity", "cybersécurité",
    "pentest", "pentester", "soc", "threat", "vulnerability",
    # QA & Test
    "qa", "quality", "qualité", "test", "testing", "automation",
    "sdet", "assurance qualité",
    # Architecture & Leadership tech
    "architect", "architecte", "architecture",
    "tech lead", "team lead", "lead", "principal",
    "cto", "vp engineering", "director of engineering",
    "manager", "gestionnaire",
    # Spécialisations
    "embedded", "embarqué", "firmware", "iot",
    "blockchain", "smart contract",
    "game", "jeux", "unity", "unreal",
    "ux", "ui", "design", "designer", "product",
    "scrum", "agile", "project", "projet",
    "support", "helpdesk", "help desk", "it support",
    "erp", "sap", "salesforce", "crm",
    # Termes génériques IT
    "it", "tic", "informatique", "numérique", "digital", "tech", "technicien",
    "consultant", "consulting",
}

# Longueur max pour un titre de poste
_MAX_LENGTH = 100


def validate_job_title(title: str) -> str:
    """Valide et nettoie un titre de poste IT.

    Raises HTTPException 400 si :
    - Le titre est vide ou trop long
    - Le titre contient des caractères spéciaux non autorisés
    - Le titre ne correspond pas à un métier IT
    """
    if not title or not title.strip():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Job title is required",
        )

    title = title.strip()

    if len(title) > _MAX_LENGTH:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Job title too long (max {_MAX_LENGTH} characters)",
        )

    if not _ALLOWED_PATTERN.match(title):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Job title contains invalid characters",
        )

    # Vérifier qu'au moins un mot-clé IT est présent
    title_lower = title.lower()
    if not any(kw in title_lower for kw in _IT_KEYWORDS):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Job title must be related to IT/tech",
        )

    return title


def validate_job_titles(titles: list[str]) -> list[str]:
    """Valide une liste de titres de poste (pour les target_jobs du roadmap)."""
    return [validate_job_title(t) for t in titles]
