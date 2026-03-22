# Tests pour services/coach/coach_prompt_builder.py.

from services.coach.coach_prompt_builder import build_coach_prompt


class TestBuildCoachPrompt:
    def test_returns_tuple(self):
        system, user = build_coach_prompt("CV text", "Job desc")
        assert isinstance(system, str)
        assert isinstance(user, str)

    def test_system_contains_json_structure(self):
        system, _ = build_coach_prompt("CV", "Job")
        assert '"compatibility_score"' in system
        assert '"ats_analysis"' in system
        assert '"recommendations"' in system

    def test_user_contains_cv_and_job(self):
        _, user = build_coach_prompt("Mon CV contenu", "Description offre")
        assert "Mon CV contenu" in user
        assert "Description offre" in user

    def test_french_language(self):
        system, _ = build_coach_prompt("CV", "Job", language="fr")
        assert "français" in system.lower()

    def test_english_language(self):
        system, _ = build_coach_prompt("CV", "Job", language="en")
        assert "English" in system

    def test_default_language_is_french(self):
        system, _ = build_coach_prompt("CV", "Job")
        assert "français" in system.lower()
