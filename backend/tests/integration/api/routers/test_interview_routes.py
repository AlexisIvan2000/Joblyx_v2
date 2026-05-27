"""Tests pour api/routers/interview.py."""

from unittest.mock import AsyncMock, MagicMock

import pytest
from fastapi import HTTPException

from tests.conftest import FAKE_USER_ID


FAKE_SESSION_ID = "33333333-3333-3333-3333-333333333333"


def _mock_session(**overrides):
    """Construit un objet session simulé."""
    s = MagicMock()
    s.id = FAKE_SESSION_ID
    s.user_id = FAKE_USER_ID
    s.job_title = "Software Engineer"
    s.company_name = "Google"
    s.job_description = "Build stuff"
    s.status = "in_progress"
    s.language = "fr"
    s.overall_score = None
    s.category_scores = None
    s.summary = None
    s.created_at = "2026-01-01T00:00:00"
    s.completed_at = None
    s.messages = []
    for k, v in overrides.items():
        setattr(s, k, v)
    return s


def _mock_message(**overrides):
    """Construit un objet message simulé."""
    m = MagicMock()
    m.id = "44444444-4444-4444-4444-444444444444"
    m.role = "assistant"
    m.content = "Tell me about yourself"
    m.feedback = None
    m.position = 0
    for k, v in overrides.items():
        setattr(m, k, v)
    return m


@pytest.fixture
def test_client_with_interview(test_client):
    """Ajoute un mock InterviewService au test_client existant."""
    from app import app
    from api.v1.client.interview import get_interview_service

    interview_svc = AsyncMock()

    # Valeurs par défaut
    interview_svc.start_session.return_value = {
        "id": FAKE_SESSION_ID,
        "status": "in_progress",
        "job_title": "Dev",
        "company_name": None,
        "language": "fr",
    }
    interview_svc.end_session_early.return_value = {
        "id": FAKE_SESSION_ID,
        "status": "completed",
    }
    interview_svc.check_usage.return_value = {
        "used": 2,
        "limit": 10,
        "remaining": 8,
    }
    interview_svc.get_history.return_value = []
    interview_svc.get_session.return_value = _mock_session()
    interview_svc.delete_session.return_value = None
    interview_svc.delete_all.return_value = 3

    async def override():
        return interview_svc

    app.dependency_overrides[get_interview_service] = override
    test_client._mock_interview_svc = interview_svc
    yield test_client
    del app.dependency_overrides[get_interview_service]


# ─── Démarrer un entretien ──────────────────────────────────────


class TestStartSession:
    def test_success(self, test_client_with_interview):
        client = test_client_with_interview
        svc = client._mock_interview_svc

        resp = client.post(
            "/assistant/interview/start",
            data={"job_title": "Dev", "language": "fr"},
        )

        assert resp.status_code == 200
        body = resp.json()
        assert body["id"] == FAKE_SESSION_ID
        assert body["status"] == "in_progress"
        svc.start_session.assert_called_once()

    def test_with_all_fields(self, test_client_with_interview):
        client = test_client_with_interview
        svc = client._mock_interview_svc
        svc.start_session.return_value = {
            "id": FAKE_SESSION_ID,
            "status": "in_progress",
            "job_title": "Backend Dev",
            "company_name": "Google",
            "language": "en",
        }

        resp = client.post(
            "/assistant/interview/start",
            data={
                "job_title": "Backend Dev",
                "company_name": "Google",
                "job_description": "Build APIs",
                "language": "en",
            },
        )

        assert resp.status_code == 200
        body = resp.json()
        assert body["job_title"] == "Backend Dev"
        assert body["company_name"] == "Google"


# ─── Terminer un entretien ──────────────────────────────────────


class TestEndSession:
    def test_success(self, test_client_with_interview):
        client = test_client_with_interview
        svc = client._mock_interview_svc

        resp = client.post(f"/assistant/interview/{FAKE_SESSION_ID}/end")

        assert resp.status_code == 200
        body = resp.json()
        assert body["status"] == "completed"
        svc.end_session_early.assert_called_once_with(
            FAKE_SESSION_ID, str(FAKE_USER_ID),
        )


# ─── Usage ──────────────────────────────────────────────────────


class TestGetUsage:
    def test_returns_dict(self, test_client_with_interview):
        client = test_client_with_interview

        resp = client.get("/assistant/interview/usage")

        assert resp.status_code == 200
        body = resp.json()
        assert body["used"] == 2
        assert body["limit"] == 10
        assert body["remaining"] == 8


# ─── Historique ─────────────────────────────────────────────────


class TestGetHistory:
    def test_empty(self, test_client_with_interview):
        client = test_client_with_interview
        svc = client._mock_interview_svc
        svc.get_history.return_value = []

        resp = client.get("/assistant/interview/history")

        assert resp.status_code == 200
        assert resp.json() == []

    def test_populated(self, test_client_with_interview):
        client = test_client_with_interview
        svc = client._mock_interview_svc

        session = _mock_session()
        msg = _mock_message(content="Bonjour, parlez-moi de vous")
        session.messages = [msg]
        # created_at doit avoir une méthode .isoformat()
        session.created_at = MagicMock()
        session.created_at.isoformat.return_value = "2026-01-01T00:00:00"
        svc.get_history.return_value = [session]

        resp = client.get("/assistant/interview/history")

        assert resp.status_code == 200
        body = resp.json()
        assert len(body) == 1
        assert body[0]["id"] == FAKE_SESSION_ID
        assert body[0]["job_title"] == "Software Engineer"
        assert body[0]["last_message"] == "Bonjour, parlez-moi de vous"


# ─── Détail session ────────────────────────────────────────────


class TestGetSession:
    def test_returns_session_with_messages(self, test_client_with_interview):
        client = test_client_with_interview
        svc = client._mock_interview_svc

        msg = _mock_message()
        session = _mock_session(messages=[msg])
        # created_at / completed_at doivent supporter .isoformat()
        session.created_at = MagicMock()
        session.created_at.isoformat.return_value = "2026-01-01T00:00:00"
        session.completed_at = None
        svc.get_session.return_value = session

        resp = client.get(f"/assistant/interview/{FAKE_SESSION_ID}")

        assert resp.status_code == 200
        body = resp.json()
        assert body["id"] == FAKE_SESSION_ID
        assert body["job_title"] == "Software Engineer"
        assert len(body["messages"]) == 1
        assert body["messages"][0]["role"] == "assistant"
        assert body["messages"][0]["content"] == "Tell me about yourself"

    def test_returns_404_when_not_found(self, test_client_with_interview):
        client = test_client_with_interview
        svc = client._mock_interview_svc
        svc.get_session.side_effect = HTTPException(
            status_code=404, detail="Session not found",
        )

        resp = client.get(f"/assistant/interview/{FAKE_SESSION_ID}")

        assert resp.status_code == 404


# ─── Bilan / Summary ───────────────────────────────────────────


class TestGetSummary:
    def test_returns_summary_when_completed(self, test_client_with_interview):
        client = test_client_with_interview
        svc = client._mock_interview_svc

        session = _mock_session(
            status="completed",
            overall_score=78,
            category_scores={"technical": 80, "behavioral": 75},
            summary="Good performance overall.",
        )
        svc.get_session.return_value = session

        resp = client.get(f"/assistant/interview/{FAKE_SESSION_ID}/summary")

        assert resp.status_code == 200
        body = resp.json()
        assert body["overall_score"] == 78
        assert body["category_scores"]["technical"] == 80
        assert body["summary"] == "Good performance overall."

    def test_returns_400_when_not_completed(self, test_client_with_interview):
        client = test_client_with_interview
        svc = client._mock_interview_svc

        session = _mock_session(status="in_progress")
        svc.get_session.return_value = session

        resp = client.get(f"/assistant/interview/{FAKE_SESSION_ID}/summary")

        assert resp.status_code == 400
        assert "not completed" in resp.json()["message"].lower()


# ─── Suppression d'une session ──────────────────────────────────


class TestDeleteSession:
    def test_success(self, test_client_with_interview):
        client = test_client_with_interview
        svc = client._mock_interview_svc

        resp = client.delete(f"/assistant/interview/{FAKE_SESSION_ID}")

        assert resp.status_code == 200
        assert resp.json()["message"] == "Session deleted"
        svc.delete_session.assert_called_once_with(
            FAKE_SESSION_ID, str(FAKE_USER_ID),
        )

    def test_returns_404_when_not_found(self, test_client_with_interview):
        client = test_client_with_interview
        svc = client._mock_interview_svc
        svc.delete_session.side_effect = HTTPException(
            status_code=404, detail="Session not found",
        )

        resp = client.delete(f"/assistant/interview/{FAKE_SESSION_ID}")

        assert resp.status_code == 404


# ─── Suppression de toutes les sessions ─────────────────────────


class TestDeleteAll:
    def test_success(self, test_client_with_interview):
        client = test_client_with_interview
        svc = client._mock_interview_svc
        svc.delete_all.return_value = 3

        resp = client.delete("/assistant/interview")

        assert resp.status_code == 200
        body = resp.json()
        assert body["count"] == 3
        assert "3" in body["message"]
        svc.delete_all.assert_called_once_with(str(FAKE_USER_ID))
