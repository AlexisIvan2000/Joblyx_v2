"""Tests pour services/roadmap/prompt_builder.py."""

import pytest
from services.roadmap.prompt_builder import build_roadmap_prompt


def _career(**overrides):
    defaults = {
        "level": "junior",
        "years_experience": 2,
        "target_jobs": ["Software Developer"],
        "city": "Toronto",
        "province": "ON",
        "language": "en",
        "previous_field": None,
    }
    defaults.update(overrides)
    return defaults


def _skills():
    return [
        {"skill_name": "Python", "category": "programming_languages", "proficiency": "advanced"},
        {"skill_name": "Django", "category": "backend_frameworks", "proficiency": "intermediate"},
    ]


class TestBuildRoadmapPrompt:
    def test_returns_two_strings(self):
        sys_p, usr_p = build_roadmap_prompt(_career(), _skills(), None)
        assert isinstance(sys_p, str)
        assert isinstance(usr_p, str)
        assert len(sys_p) > 100
        assert len(usr_p) > 100

    def test_includes_user_skills(self):
        _, usr_p = build_roadmap_prompt(_career(), _skills(), None)
        assert "Python" in usr_p
        assert "Django" in usr_p
        assert "advanced" in usr_p

    def test_includes_target_jobs(self):
        _, usr_p = build_roadmap_prompt(_career(), _skills(), None)
        assert "Software Developer" in usr_p

    def test_includes_location(self):
        _, usr_p = build_roadmap_prompt(_career(), _skills(), None)
        assert "Toronto" in usr_p
        assert "ON" in usr_p

    def test_french_language(self):
        sys_p, _ = build_roadmap_prompt(_career(language="fr"), _skills(), None)
        assert "français" in sys_p.lower()

    def test_english_language(self):
        sys_p, _ = build_roadmap_prompt(_career(language="en"), _skills(), None)
        assert "english" in sys_p.lower()

    def test_without_market_data(self):
        _, usr_p = build_roadmap_prompt(_career(), _skills(), None)
        assert "connaissance du marché" in usr_p.lower() or "ta connaissance" in usr_p.lower()

    def test_with_market_data(self):
        market = [
            {"name": "Kubernetes", "count": 38, "percentage": 76},
            {"name": "AWS", "count": 30, "percentage": 60},
        ]
        _, usr_p = build_roadmap_prompt(_career(), _skills(), market)
        assert "Kubernetes" in usr_p
        assert "76%" in usr_p
        assert "Complète avec" in usr_p or "Complète cette liste" in usr_p

    def test_reconversion_with_previous_field(self):
        career = _career(level="reconversion", previous_field="Marketing")
        _, usr_p = build_roadmap_prompt(career, _skills(), None)
        assert "reconversion" in usr_p.lower()
        assert "Marketing" in usr_p

    def test_json_structure_in_system_prompt(self):
        sys_p, _ = build_roadmap_prompt(_career(), _skills(), None)
        assert '"phases"' in sys_p
        assert '"duration_weeks"' in sys_p
        assert '"resources"' in sys_p
        assert '"milestone"' in sys_p
