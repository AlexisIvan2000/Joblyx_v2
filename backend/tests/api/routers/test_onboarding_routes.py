"""Tests for api/routers/onboarding.py — onboarding route HTTP layer."""

from tests.conftest import FAKE_USER_ID


VALID_BODY = {
    "level": "junior",
    "years_experience": 2,
    "target_jobs": ["Developer"],
    "city": "Montreal",
    "province": "Quebec",
    "language": "fr",
    "skills": [{"skill_name": "Python", "category": "Programming", "level": "advanced"}],
}


class TestOnboardingRoute:
    def test_success_202(self, test_client):
        resp = test_client.post("/onboarding", json=VALID_BODY)
        assert resp.status_code == 202
        data = resp.json()
        assert "roadmap_id" in data
        assert data["message"] == "Onboarding completed successfully"

    def test_invalid_body_returns_422(self, test_client):
        resp = test_client.post("/onboarding", json={})
        assert resp.status_code == 422

    def test_too_many_target_jobs_returns_422(self, test_client):
        body = {**VALID_BODY, "target_jobs": ["A", "B", "C", "D"]}
        resp = test_client.post("/onboarding", json=body)
        assert resp.status_code == 422

    def test_empty_skills_returns_422(self, test_client):
        body = {**VALID_BODY, "skills": []}
        resp = test_client.post("/onboarding", json=body)
        assert resp.status_code == 422

    def test_invalid_skill_level_returns_422(self, test_client):
        body = {**VALID_BODY, "skills": [{"skill_name": "X", "category": "Y", "level": "expert"}]}
        resp = test_client.post("/onboarding", json=body)
        assert resp.status_code == 422

    def test_three_target_jobs_ok(self, test_client):
        body = {**VALID_BODY, "target_jobs": ["Dev", "PM", "QA"]}
        resp = test_client.post("/onboarding", json=body)
        assert resp.status_code == 202
