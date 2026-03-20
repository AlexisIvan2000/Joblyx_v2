"""Tests pour api/routers/roadmap.py."""

from datetime import datetime, timezone
from unittest.mock import AsyncMock, MagicMock

import pytest

from tests.conftest import FAKE_USER_ID


VALID_GENERATE_BODY = {
    "level": "junior",
    "years_experience": 2,
    "target_jobs": ["Developer"],
    "city": "Montreal",
    "province": "Quebec",
    "language": "fr",
    "skills": [{"skill_name": "Python", "category": "Programming", "proficiency": "advanced"}],
}


def _mock_roadmap(phases=None, status="active"):
    rm = MagicMock()
    rm.id = "aaaa-bbbb"
    rm.summary = {"overview": "Test"}
    rm.status = status
    rm.created_at = datetime(2026, 1, 1, tzinfo=timezone.utc)
    rm.phases = phases or []
    return rm


def _mock_phase(**overrides):
    import uuid
    defaults = {
        "id": uuid.uuid4(),
        "phase_number": 1,
        "title": "Phase 1",
        "duration_weeks": 4,
        "objective": "Learn basics",
        "skills": [],
        "actions": [],
        "resources": [],
        "certifications": [],
        "projects": [],
        "milestone": "Done",
        "completed": False,
        "custom": False,
        "user_notes": None,
        "position": 0,
    }
    defaults.update(overrides)
    return MagicMock(**defaults)


class TestPostGenerate:
    def test_returns_sse_stream(self, test_client):
        resp = test_client.post("/roadmap/generate", json=VALID_GENERATE_BODY)
        assert resp.status_code == 200
        assert resp.headers["content-type"].startswith("text/event-stream")
        assert "generating" in resp.text

    def test_saves_career_and_skills(self, test_client):
        svc = test_client._mock_roadmap_svc
        test_client.post("/roadmap/generate", json=VALID_GENERATE_BODY)
        svc.save_career_and_skills.assert_called_once()

    def test_skips_regen_limit_on_first_time(self, test_client):
        svc = test_client._mock_roadmap_svc
        svc.save_career_and_skills.return_value = True
        resp = test_client.post("/roadmap/generate", json=VALID_GENERATE_BODY)
        assert resp.status_code == 200
        svc.check_regeneration_limit.assert_not_called()

    def test_returns_429_when_limit_reached(self, test_client):
        svc = test_client._mock_roadmap_svc
        svc.save_career_and_skills.return_value = False
        svc.check_regeneration_limit.return_value = {
            "allowed": False, "used": 5, "remaining": 0, "resets_at": "2026-04-01T00:00:00+00:00",
        }
        resp = test_client.post("/roadmap/generate", json=VALID_GENERATE_BODY)
        assert resp.status_code == 429


class TestGetStatus:
    def test_returns_status_with_roadmap(self, test_client):
        svc = test_client._mock_roadmap_svc
        svc._get_career.return_value = MagicMock(generation_status="ready")
        svc.repo.get_active_roadmap.return_value = _mock_roadmap()

        resp = test_client.get("/roadmap/status")
        assert resp.status_code == 200
        data = resp.json()
        assert data["generation_status"] == "ready"
        assert data["has_roadmap"] is True

    def test_returns_status_without_roadmap(self, test_client):
        svc = test_client._mock_roadmap_svc
        svc._get_career.return_value = MagicMock(generation_status="idle")
        svc.repo.get_active_roadmap.return_value = None

        resp = test_client.get("/roadmap/status")
        assert resp.status_code == 200
        data = resp.json()
        assert data["generation_status"] == "idle"
        assert data["has_roadmap"] is False

    def test_returns_idle_when_no_career(self, test_client):
        svc = test_client._mock_roadmap_svc
        svc._get_career.return_value = None
        svc.repo.get_active_roadmap.return_value = None

        resp = test_client.get("/roadmap/status")
        assert resp.status_code == 200
        data = resp.json()
        assert data["generation_status"] == "idle"
        assert data["has_roadmap"] is False


class TestGetRoadmap:
    def test_returns_active_roadmap(self, test_client):
        svc = test_client._mock_roadmap_svc
        phase = _mock_phase()
        svc.repo.get_active_roadmap.return_value = _mock_roadmap(phases=[phase])

        resp = test_client.get("/roadmap")
        assert resp.status_code == 200
        data = resp.json()
        assert data["id"] == "aaaa-bbbb"
        assert data["status"] == "active"
        assert len(data["phases"]) == 1

    def test_returns_404_when_no_active(self, test_client):
        svc = test_client._mock_roadmap_svc
        svc.repo.get_active_roadmap.return_value = None

        resp = test_client.get("/roadmap")
        assert resp.status_code == 404


class TestGetHistory:
    def test_returns_archived_list(self, test_client):
        svc = test_client._mock_roadmap_svc
        svc.repo.get_history.return_value = [
            _mock_roadmap(status="archived"),
        ]

        resp = test_client.get("/roadmap/history")
        assert resp.status_code == 200
        data = resp.json()
        assert len(data) == 1
        assert data[0]["status"] == "archived"

    def test_returns_empty_list(self, test_client):
        svc = test_client._mock_roadmap_svc
        svc.repo.get_history.return_value = []

        resp = test_client.get("/roadmap/history")
        assert resp.status_code == 200
        assert resp.json() == []
