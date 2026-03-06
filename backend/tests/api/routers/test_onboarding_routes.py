"""Tests for api/routers/onboarding.py — HTTP layer."""

import pytest


VALID_BODY = {
    "level": "junior",
    "years_experience": 2,
    "target_jobs": ["Developer"],
    "city": "Montreal",
    "province": "Quebec",
    "language": "fr",
    "skills": [{"skill_name": "Python", "category": "Programming", "proficiency": "advanced"}],
}


# ─── POST /onboarding ──────────────────────────────────────────────

class TestPostOnboarding:
    def test_success_returns_200(self, test_client):
        resp = test_client.post("/onboarding", json=VALID_BODY)
        assert resp.status_code == 200
        data = resp.json()
        assert data["onboarding_completed"] is True
        assert data["level"] == "junior"
        assert len(data["skills"]) >= 1

    def test_invalid_body_returns_422(self, test_client):
        resp = test_client.post("/onboarding", json={})
        assert resp.status_code == 422

    def test_empty_skills_returns_422(self, test_client):
        body = {**VALID_BODY, "skills": []}
        resp = test_client.post("/onboarding", json=body)
        assert resp.status_code == 422

    def test_invalid_level_returns_422(self, test_client):
        body = {**VALID_BODY, "level": "expert"}
        resp = test_client.post("/onboarding", json=body)
        assert resp.status_code == 422

    def test_too_many_target_jobs_returns_422(self, test_client):
        body = {**VALID_BODY, "target_jobs": ["A", "B", "C", "D"]}
        resp = test_client.post("/onboarding", json=body)
        assert resp.status_code == 422

    def test_already_completed_returns_409(self, test_client):
        test_client._mock_onboarding_repo.has_profile.return_value = True
        resp = test_client.post("/onboarding", json=VALID_BODY)
        assert resp.status_code == 409


# ─── GET /onboarding/status ────────────────────────────────────────

class TestGetOnboardingStatus:
    def test_no_profile(self, test_client):
        test_client._mock_onboarding_repo.has_profile.return_value = False
        resp = test_client.get("/onboarding/status")
        assert resp.status_code == 200
        assert resp.json() == {"has_profile": False}

    def test_has_profile(self, test_client):
        test_client._mock_onboarding_repo.has_profile.return_value = True
        resp = test_client.get("/onboarding/status")
        assert resp.status_code == 200
        assert resp.json() == {"has_profile": True}


# ─── GET /onboarding ───────────────────────────────────────────────

class TestGetOnboarding:
    def test_success(self, test_client):
        resp = test_client.get("/onboarding")
        assert resp.status_code == 200
        data = resp.json()
        assert data["level"] == "junior"
        assert data["onboarding_completed"] is True

    def test_no_profile_returns_404(self, test_client):
        test_client._mock_onboarding_repo.get_career_by_user_id.return_value = None
        resp = test_client.get("/onboarding")
        assert resp.status_code == 404


# ─── PUT /onboarding ───────────────────────────────────────────────

class TestPutOnboarding:
    def test_success(self, test_client):
        resp = test_client.put("/onboarding", json=VALID_BODY)
        assert resp.status_code == 200
        data = resp.json()
        assert data["onboarding_completed"] is True

    def test_no_profile_returns_404(self, test_client):
        test_client._mock_onboarding_repo.get_career_by_user_id.return_value = None
        resp = test_client.put("/onboarding", json=VALID_BODY)
        assert resp.status_code == 404

    def test_invalid_body_returns_422(self, test_client):
        resp = test_client.put("/onboarding", json={})
        assert resp.status_code == 422
