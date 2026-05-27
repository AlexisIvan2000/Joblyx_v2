import pytest

from datetime import datetime, timezone
from unittest.mock import AsyncMock, MagicMock
from fastapi import HTTPException
from tests.conftest import FAKE_USER_ID


FAKE_SESSION_ID = "33333333-3333-3333-3333-333333333333"


def _mock_session(**overrides):
    defaults = {
        "id": FAKE_SESSION_ID,
        "user_id": FAKE_USER_ID,
        "job_title": "Software Engineer",
        "company_name": "Google",
        "job_description": "Build stuff",
        "compatibility_score": 85,
        "analysis": {"strengths": ["Python"], "weaknesses": ["Java"]},
        "language": "fr",
        "created_at": datetime(2026, 1, 1, tzinfo=timezone.utc),
    }
    defaults.update(overrides)
    return MagicMock(**defaults)


@pytest.fixture
def test_client_with_coach(test_client):
    
    from app import app
    from api.v1.client.coach import get_coach_service

    coach_svc = AsyncMock()
    # Valeurs par défaut raisonnables
    coach_svc.get_history.return_value = []
    coach_svc.check_usage.return_value = {
        "used": 2, "limit": 10, "remaining": 8,
    }
    coach_svc.get_session.return_value = _mock_session()
    coach_svc.delete_session.return_value = None
    coach_svc.delete_all.return_value = 0

    async def override():
        return coach_svc

    app.dependency_overrides[get_coach_service] = override
    test_client._mock_coach_svc = coach_svc
    yield test_client
    del app.dependency_overrides[get_coach_service]


#  Historique


class TestGetHistory:
    def test_returns_empty_list(self, test_client_with_coach):
        svc = test_client_with_coach._mock_coach_svc
        svc.get_history.return_value = []

        resp = test_client_with_coach.get("/assistant/coach/history")
        assert resp.status_code == 200
        assert resp.json() == []
        svc.get_history.assert_called_once_with(str(FAKE_USER_ID))

    def test_returns_populated_list(self, test_client_with_coach):
        svc = test_client_with_coach._mock_coach_svc
        svc.get_history.return_value = [
            _mock_session(),
            _mock_session(
                id="44444444-4444-4444-4444-444444444444",
                job_title="Data Scientist",
                company_name="Meta",
                compatibility_score=72,
            ),
        ]

        resp = test_client_with_coach.get("/assistant/coach/history")
        assert resp.status_code == 200
        body = resp.json()
        assert len(body) == 2
        assert body[0]["id"] == FAKE_SESSION_ID
        assert body[0]["job_title"] == "Software Engineer"
        assert body[0]["company_name"] == "Google"
        assert body[0]["compatibility_score"] == 85
        assert body[0]["created_at"] is not None
        assert body[1]["job_title"] == "Data Scientist"


#  Usage 


class TestGetUsage:
    def test_returns_usage_dict(self, test_client_with_coach):
        svc = test_client_with_coach._mock_coach_svc
        svc.check_usage.return_value = {
            "used": 3, "limit": 10, "remaining": 7,
        }

        resp = test_client_with_coach.get("/assistant/coach/usage")
        assert resp.status_code == 200
        body = resp.json()
        assert body["used"] == 3
        assert body["limit"] == 10
        assert body["remaining"] == 7
        svc.check_usage.assert_called_once_with(str(FAKE_USER_ID))


#  Détail d'une session 


class TestGetSession:
    def test_returns_session(self, test_client_with_coach):
        svc = test_client_with_coach._mock_coach_svc
        svc.get_session.return_value = _mock_session()

        resp = test_client_with_coach.get(f"/assistant/coach/{FAKE_SESSION_ID}")
        assert resp.status_code == 200
        body = resp.json()
        assert body["id"] == FAKE_SESSION_ID
        assert body["job_title"] == "Software Engineer"
        assert body["company_name"] == "Google"
        assert body["job_description"] == "Build stuff"
        assert body["compatibility_score"] == 85
        assert body["analysis"] == {"strengths": ["Python"], "weaknesses": ["Java"]}
        assert body["language"] == "fr"
        assert body["created_at"] is not None
        svc.get_session.assert_called_once_with(FAKE_SESSION_ID, str(FAKE_USER_ID))

    def test_returns_404_when_not_found(self, test_client_with_coach):
        svc = test_client_with_coach._mock_coach_svc
        svc.get_session.side_effect = HTTPException(status_code=404, detail="Not found")

        resp = test_client_with_coach.get(f"/assistant/coach/{FAKE_SESSION_ID}")
        assert resp.status_code == 404


#  Suppression d'une session 


class TestDeleteSession:
    def test_deletes_session(self, test_client_with_coach):
        svc = test_client_with_coach._mock_coach_svc
        svc.delete_session.return_value = None

        resp = test_client_with_coach.delete(f"/assistant/coach/{FAKE_SESSION_ID}")
        assert resp.status_code == 200
        assert resp.json()["message"] == "Session deleted"
        svc.delete_session.assert_called_once_with(FAKE_SESSION_ID, str(FAKE_USER_ID))

    def test_returns_404_when_not_found(self, test_client_with_coach):
        svc = test_client_with_coach._mock_coach_svc
        svc.delete_session.side_effect = HTTPException(status_code=404, detail="Not found")

        resp = test_client_with_coach.delete(f"/assistant/coach/{FAKE_SESSION_ID}")
        assert resp.status_code == 404


#  Suppression de toutes les sessions 


class TestDeleteAll:
    def test_deletes_all_sessions(self, test_client_with_coach):
        svc = test_client_with_coach._mock_coach_svc
        svc.delete_all.return_value = 5

        resp = test_client_with_coach.delete("/assistant/coach")
        assert resp.status_code == 200
        body = resp.json()
        assert body["count"] == 5
        assert "5 session(s) deleted" in body["message"]
        svc.delete_all.assert_called_once_with(str(FAKE_USER_ID))
