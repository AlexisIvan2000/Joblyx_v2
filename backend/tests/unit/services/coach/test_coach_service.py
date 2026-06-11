

from datetime import datetime, timezone, timedelta
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from services.coach.coach_service import (
    CoachService,
    _get_next_monday,
    _get_current_week_monday,
    WEEKLY_LIMIT,
)
from tests.conftest import FAKE_USER_ID


@pytest.fixture
def mock_session():
    session = AsyncMock()
    session.commit = AsyncMock()
    return session


@pytest.fixture
def service(mock_session):
    return CoachService(mock_session)


class TestWeeklyHelpers:
    def test_next_monday_is_in_future(self):
        result = _get_next_monday()
        assert result > datetime.now(timezone.utc)
        assert result.weekday() == 0  # Lundi

    def test_current_week_monday_is_monday(self):
        result = _get_current_week_monday()
        assert result.weekday() == 0

    def test_current_week_monday_is_in_past_or_today(self):
        result = _get_current_week_monday()
        assert result <= datetime.now(timezone.utc)


class TestCheckUsage:
    @pytest.mark.asyncio
    async def test_returns_usage_within_limit(self, service):
        service.repo = AsyncMock()
        service.repo.get_usage.return_value = {
            "coach_usage_count": 1,
            "coach_usage_reset_at": datetime.now(timezone.utc),
        }

        result = await service.check_usage(FAKE_USER_ID)
        assert result["used"] == 1
        assert result["remaining"] == WEEKLY_LIMIT - 1
        assert result["limit"] == WEEKLY_LIMIT

    @pytest.mark.asyncio
    async def test_resets_count_on_new_week(self, service):
        service.repo = AsyncMock()
        # Reset date d'il y a 2 semaines
        old_reset = datetime.now(timezone.utc) - timedelta(weeks=2)
        service.repo.get_usage.return_value = {
            "coach_usage_count": 3,
            "coach_usage_reset_at": old_reset,
        }

        result = await service.check_usage(FAKE_USER_ID)
        assert result["used"] == 0
        assert result["remaining"] == WEEKLY_LIMIT
        service.repo.reset_usage.assert_called_once()

    @pytest.mark.asyncio
    async def test_limit_reached(self, service):
        service.repo = AsyncMock()
        service.repo.get_usage.return_value = {
            "coach_usage_count": WEEKLY_LIMIT,
            "coach_usage_reset_at": datetime.now(timezone.utc),
        }

        result = await service.check_usage(FAKE_USER_ID)
        assert result["remaining"] == 0


class TestGetSession:
    @pytest.mark.asyncio
    async def test_returns_session(self, service):
        fake = MagicMock()
        service.repo = AsyncMock()
        service.repo.get_by_id.return_value = fake

        result = await service.get_session("s1", FAKE_USER_ID)
        assert result == fake

    @pytest.mark.asyncio
    async def test_raises_404_when_not_found(self, service):
        from core.exceptions import SessionNotFound
        service.repo = AsyncMock()
        service.repo.get_by_id.return_value = None

        with pytest.raises(SessionNotFound):
            await service.get_session("s1", FAKE_USER_ID)


class TestDeleteSession:
    @pytest.mark.asyncio
    async def test_deletes_session_and_cv(self, service, mock_session):
        fake = MagicMock(cv_file_key="user/cv.pdf")
        service.repo = AsyncMock()
        service.repo.delete_session.return_value = fake
        service.r2 = AsyncMock()

        await service.delete_session("s1", FAKE_USER_ID)
        service.r2.delete_cv.assert_called_once_with("user/cv.pdf")
        mock_session.commit.assert_called_once()

    @pytest.mark.asyncio
    async def test_raises_404_when_not_found(self, service):
        from core.exceptions import SessionNotFound
        service.repo = AsyncMock()
        service.repo.delete_session.return_value = None

        with pytest.raises(SessionNotFound):
            await service.delete_session("s1", FAKE_USER_ID)


class TestDeleteAll:
    @pytest.mark.asyncio
    async def test_deletes_all_and_cleans_r2(self, service, mock_session):
        service.repo = AsyncMock()
        service.repo.delete_all_by_user.return_value = ["k1.pdf", "k2.pdf"]
        service.r2 = AsyncMock()

        count = await service.delete_all(FAKE_USER_ID)
        assert count == 2
        assert service.r2.delete_cv.call_count == 2
