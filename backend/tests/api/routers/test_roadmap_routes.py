"""Tests pour api/routers/roadmap.py."""

from datetime import datetime, timezone
from unittest.mock import AsyncMock, MagicMock, patch

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


class TestPostGenerate:
    def test_returns_generating_status(self, test_client):
        resp = test_client.post("/roadmap/generate", json=VALID_GENERATE_BODY)
        assert resp.status_code == 200
        assert resp.json()["status"] == "generating"

    def test_saves_career_and_skills(self, test_client):
        svc = test_client._mock_roadmap_svc
        test_client.post("/roadmap/generate", json=VALID_GENERATE_BODY)
        svc.save_career_and_skills.assert_called_once()

    def test_skips_regen_limit_on_first_time(self, test_client):
        svc = test_client._mock_roadmap_svc
        svc.save_career_and_skills.return_value = True  # is_first
        resp = test_client.post("/roadmap/generate", json=VALID_GENERATE_BODY)
        assert resp.status_code == 200
        svc.check_regeneration_limit.assert_not_called()

    def test_checks_regen_limit_on_subsequent(self, test_client):
        svc = test_client._mock_roadmap_svc
        svc.save_career_and_skills.return_value = False  # not first
        resp = test_client.post("/roadmap/generate", json=VALID_GENERATE_BODY)
        assert resp.status_code == 200
        svc.check_regeneration_limit.assert_called_once()

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
        svc.repo.get_active_by_user_id.return_value = MagicMock()

        resp = test_client.get("/roadmap/status")
        assert resp.status_code == 200
        data = resp.json()
        assert data["generation_status"] == "ready"
        assert data["has_roadmap"] is True

    def test_returns_status_without_roadmap(self, test_client):
        svc = test_client._mock_roadmap_svc
        svc._get_career.return_value = MagicMock(generation_status="idle")
        svc.repo.get_active_by_user_id.return_value = None

        resp = test_client.get("/roadmap/status")
        assert resp.status_code == 200
        data = resp.json()
        assert data["generation_status"] == "idle"
        assert data["has_roadmap"] is False

    def test_returns_idle_when_no_career(self, test_client):
        svc = test_client._mock_roadmap_svc
        svc._get_career.return_value = None
        svc.repo.get_active_by_user_id.return_value = None

        resp = test_client.get("/roadmap/status")
        assert resp.status_code == 200
        data = resp.json()
        assert data["generation_status"] == "idle"
        assert data["has_roadmap"] is False


class TestGetRoadmap:
    def test_returns_active_roadmap(self, test_client):
        svc = test_client._mock_roadmap_svc
        svc.repo.get_active_by_user_id.return_value = MagicMock(
            id="aaaa-bbbb",
            target_jobs=["Developer"],
            phases=[],
            status="active",
            created_at=datetime(2026, 1, 1, tzinfo=timezone.utc),
        )

        resp = test_client.get("/roadmap")
        assert resp.status_code == 200
        data = resp.json()
        assert data["id"] == "aaaa-bbbb"
        assert data["status"] == "active"

    def test_returns_404_when_no_active(self, test_client):
        svc = test_client._mock_roadmap_svc
        svc.repo.get_active_by_user_id.return_value = None

        resp = test_client.get("/roadmap")
        assert resp.status_code == 404


class TestGetHistory:
    def test_returns_archived_list(self, test_client):
        svc = test_client._mock_roadmap_svc
        svc.repo.get_history_by_user_id.return_value = [
            MagicMock(
                id="111",
                target_jobs=["Developer"],
                status="archived",
                created_at=datetime(2026, 1, 1, tzinfo=timezone.utc),
            ),
        ]

        resp = test_client.get("/roadmap/history")
        assert resp.status_code == 200
        data = resp.json()
        assert len(data) == 1
        assert data[0]["status"] == "archived"

    def test_returns_empty_list(self, test_client):
        svc = test_client._mock_roadmap_svc
        svc.repo.get_history_by_user_id.return_value = []

        resp = test_client.get("/roadmap/history")
        assert resp.status_code == 200
        assert resp.json() == []
