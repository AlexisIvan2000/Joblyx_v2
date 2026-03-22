# Tests pour repositories/coach_repository.py.

from unittest.mock import AsyncMock, MagicMock

import pytest

from repositories.coach_repository import CoachRepository
from tests.conftest import FAKE_USER_ID


@pytest.fixture
def mock_session():
    session = AsyncMock()
    session.flush = AsyncMock()
    session.delete = AsyncMock()
    session.refresh = AsyncMock()
    return session


@pytest.fixture
def repo(mock_session):
    return CoachRepository(mock_session)


class TestCreate:
    @pytest.mark.asyncio
    async def test_creates_session(self, repo, mock_session):
        data = {
            "user_id": FAKE_USER_ID,
            "job_description": "Build APIs",
            "compatibility_score": 75,
        }
        await repo.create(data)
        mock_session.add.assert_called_once()
        mock_session.flush.assert_called_once()
        mock_session.refresh.assert_called_once()


class TestGetById:
    @pytest.mark.asyncio
    async def test_returns_session_when_found(self, repo, mock_session):
        fake_session = MagicMock()
        result_mock = MagicMock()
        result_mock.scalar_one_or_none.return_value = fake_session
        mock_session.execute.return_value = result_mock

        result = await repo.get_by_id("session-1", FAKE_USER_ID)
        assert result == fake_session

    @pytest.mark.asyncio
    async def test_returns_none_when_not_found(self, repo, mock_session):
        result_mock = MagicMock()
        result_mock.scalar_one_or_none.return_value = None
        mock_session.execute.return_value = result_mock

        result = await repo.get_by_id("nonexistent", FAKE_USER_ID)
        assert result is None


class TestGetAllByUser:
    @pytest.mark.asyncio
    async def test_returns_list(self, repo, mock_session):
        fake_sessions = [MagicMock(), MagicMock()]
        result_mock = MagicMock()
        scalars_mock = MagicMock()
        scalars_mock.all.return_value = fake_sessions
        result_mock.scalars.return_value = scalars_mock
        mock_session.execute.return_value = result_mock

        result = await repo.get_all_by_user(FAKE_USER_ID)
        assert len(result) == 2


class TestDeleteSession:
    @pytest.mark.asyncio
    async def test_deletes_existing_session(self, repo, mock_session):
        fake_session = MagicMock()
        result_mock = MagicMock()
        result_mock.scalar_one_or_none.return_value = fake_session
        mock_session.execute.return_value = result_mock

        result = await repo.delete_session("session-1", FAKE_USER_ID)
        assert result == fake_session
        mock_session.delete.assert_called_once_with(fake_session)

    @pytest.mark.asyncio
    async def test_returns_none_when_not_found(self, repo, mock_session):
        result_mock = MagicMock()
        result_mock.scalar_one_or_none.return_value = None
        mock_session.execute.return_value = result_mock

        result = await repo.delete_session("nonexistent", FAKE_USER_ID)
        assert result is None
        mock_session.delete.assert_not_called()


class TestDeleteAllByUser:
    @pytest.mark.asyncio
    async def test_returns_cv_keys(self, repo, mock_session):
        result_mock = MagicMock()
        result_mock.all.return_value = [("key1.pdf",), ("key2.pdf",)]
        mock_session.execute.return_value = result_mock

        keys = await repo.delete_all_by_user(FAKE_USER_ID)
        assert len(keys) == 2
        assert "key1.pdf" in keys


class TestUsage:
    @pytest.mark.asyncio
    async def test_get_usage_returns_dict(self, repo, mock_session):
        result_mock = MagicMock()
        result_mock.one_or_none.return_value = (2, None)
        mock_session.execute.return_value = result_mock

        usage = await repo.get_usage(FAKE_USER_ID)
        assert usage["coach_usage_count"] == 2

    @pytest.mark.asyncio
    async def test_get_usage_returns_zero_when_no_user(self, repo, mock_session):
        result_mock = MagicMock()
        result_mock.one_or_none.return_value = None
        mock_session.execute.return_value = result_mock

        usage = await repo.get_usage(FAKE_USER_ID)
        assert usage["coach_usage_count"] == 0

    @pytest.mark.asyncio
    async def test_increment_usage(self, repo, mock_session):
        await repo.increment_usage(FAKE_USER_ID)
        mock_session.execute.assert_called_once()
        mock_session.flush.assert_called_once()

    @pytest.mark.asyncio
    async def test_reset_usage(self, repo, mock_session):
        from datetime import datetime, timezone
        now = datetime.now(timezone.utc)
        await repo.reset_usage(FAKE_USER_ID, now)
        mock_session.execute.assert_called_once()
        mock_session.flush.assert_called_once()
