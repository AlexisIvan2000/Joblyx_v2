# Tests pour services/interview/interview_service.py.

from datetime import datetime, timezone, timedelta
from unittest.mock import AsyncMock, MagicMock

import pytest
from fastapi import HTTPException

from services.interview.interview_service import (
    InterviewService,
    _get_tomorrow_midnight,
    _get_today_midnight,
    _parse_response,
    DAILY_LIMIT,
    FEEDBACK_DELIMITER,
)
from tests.conftest import FAKE_USER_ID


@pytest.fixture
def mock_session():
    session = AsyncMock()
    session.commit = AsyncMock()
    return session


@pytest.fixture
def service(mock_session):
    return InterviewService(mock_session)


class TestHelpers:
    def test_tomorrow_midnight_is_tomorrow(self):
        result = _get_tomorrow_midnight()
        assert result > datetime.now(timezone.utc)
        assert result.hour == 0
        assert result.minute == 0

    def test_today_midnight_is_today(self):
        result = _get_today_midnight()
        assert result <= datetime.now(timezone.utc)
        assert result.hour == 0


class TestParseResponse:
    def test_parses_with_delimiter(self):
        raw = 'Bonjour, parlons de vous.\n<<<FEEDBACK_JSON>>>\n{"feedback": null, "question_type": "introduction", "question_number": 1}'
        text, feedback = _parse_response(raw)
        assert text == "Bonjour, parlons de vous."
        assert feedback["question_type"] == "introduction"
        assert feedback["question_number"] == 1

    def test_parses_without_delimiter(self):
        raw = "Just some text"
        text, feedback = _parse_response(raw)
        assert text == "Just some text"
        assert feedback is None

    def test_parses_with_feedback_score(self):
        raw = 'Bonne réponse ! Question suivante.\n<<<FEEDBACK_JSON>>>\n{"feedback": {"score": 8, "good": "bien", "improve": "plus"}, "question_type": "technical", "question_number": 3}'
        text, feedback = _parse_response(raw)
        assert "Bonne réponse" in text
        assert feedback["feedback"]["score"] == 8

    def test_handles_invalid_json_after_delimiter(self):
        raw = "Text\n<<<FEEDBACK_JSON>>>\nnot json"
        text, feedback = _parse_response(raw)
        assert text == "Text"
        assert feedback is None


class TestCheckUsage:
    @pytest.mark.asyncio
    async def test_within_limit(self, service):
        service.repo = AsyncMock()
        service.repo.get_usage.return_value = {
            "interview_usage_count": 0,
            "interview_usage_reset_at": datetime.now(timezone.utc),
        }

        result = await service.check_usage(FAKE_USER_ID)
        assert result["remaining"] == DAILY_LIMIT
        assert result["used"] == 0

    @pytest.mark.asyncio
    async def test_limit_reached(self, service):
        service.repo = AsyncMock()
        service.repo.get_usage.return_value = {
            "interview_usage_count": DAILY_LIMIT,
            "interview_usage_reset_at": datetime.now(timezone.utc),
        }

        result = await service.check_usage(FAKE_USER_ID)
        assert result["remaining"] == 0

    @pytest.mark.asyncio
    async def test_resets_on_new_day(self, service):
        service.repo = AsyncMock()
        yesterday = datetime.now(timezone.utc) - timedelta(days=1)
        service.repo.get_usage.return_value = {
            "interview_usage_count": DAILY_LIMIT,
            "interview_usage_reset_at": yesterday,
        }

        result = await service.check_usage(FAKE_USER_ID)
        assert result["used"] == 0
        assert result["remaining"] == DAILY_LIMIT
        service.repo.reset_usage.assert_called_once()


class TestGetSession:
    @pytest.mark.asyncio
    async def test_returns_session(self, service):
        fake = MagicMock()
        service.repo = AsyncMock()
        service.repo.get_session_by_id.return_value = fake

        result = await service.get_session("s1", FAKE_USER_ID)
        assert result == fake

    @pytest.mark.asyncio
    async def test_raises_404(self, service):
        service.repo = AsyncMock()
        service.repo.get_session_by_id.return_value = None

        with pytest.raises(HTTPException) as exc:
            await service.get_session("s1", FAKE_USER_ID)
        assert exc.value.status_code == 404


class TestDeleteSession:
    @pytest.mark.asyncio
    async def test_deletes(self, service, mock_session):
        service.repo = AsyncMock()
        service.repo.delete_session.return_value = True

        await service.delete_session("s1", FAKE_USER_ID)
        mock_session.commit.assert_called_once()

    @pytest.mark.asyncio
    async def test_raises_404(self, service):
        service.repo = AsyncMock()
        service.repo.delete_session.return_value = False

        with pytest.raises(HTTPException) as exc:
            await service.delete_session("s1", FAKE_USER_ID)
        assert exc.value.status_code == 404


class TestDeleteAll:
    @pytest.mark.asyncio
    async def test_returns_count(self, service, mock_session):
        service.repo = AsyncMock()
        service.repo.delete_all_by_user.return_value = 3

        count = await service.delete_all(FAKE_USER_ID)
        assert count == 3
        mock_session.commit.assert_called_once()
