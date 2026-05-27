

from unittest.mock import AsyncMock, MagicMock

import pytest

from repositories.interview_repository import InterviewRepository
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
    return InterviewRepository(mock_session)


class TestCreateSession:
    @pytest.mark.asyncio
    async def test_creates_session(self, repo, mock_session):
        await repo.create_session({"user_id": FAKE_USER_ID, "job_title": "Dev"})
        mock_session.add.assert_called_once()
        mock_session.flush.assert_called_once()
        mock_session.refresh.assert_called_once()


class TestGetSessionById:
    @pytest.mark.asyncio
    async def test_returns_session(self, repo, mock_session):
        fake = MagicMock()
        result_mock = MagicMock()
        result_mock.scalar_one_or_none.return_value = fake
        mock_session.execute.return_value = result_mock

        result = await repo.get_session_by_id("s1", FAKE_USER_ID)
        assert result == fake

    @pytest.mark.asyncio
    async def test_returns_none_when_not_found(self, repo, mock_session):
        result_mock = MagicMock()
        result_mock.scalar_one_or_none.return_value = None
        mock_session.execute.return_value = result_mock

        result = await repo.get_session_by_id("x", FAKE_USER_ID)
        assert result is None


class TestDeleteSession:
    @pytest.mark.asyncio
    async def test_deletes_existing(self, repo, mock_session):
        fake = MagicMock()
        result_mock = MagicMock()
        result_mock.scalar_one_or_none.return_value = fake
        mock_session.execute.return_value = result_mock

        result = await repo.delete_session("s1", FAKE_USER_ID)
        assert result is True
        mock_session.delete.assert_called_once()

    @pytest.mark.asyncio
    async def test_returns_false_when_not_found(self, repo, mock_session):
        result_mock = MagicMock()
        result_mock.scalar_one_or_none.return_value = None
        mock_session.execute.return_value = result_mock

        result = await repo.delete_session("x", FAKE_USER_ID)
        assert result is False


class TestCreateMessage:
    @pytest.mark.asyncio
    async def test_creates_message(self, repo, mock_session):
        await repo.create_message({"session_id": "s1", "role": "user", "content": "Hello", "position": 1})
        mock_session.add.assert_called_once()
        mock_session.flush.assert_called_once()


class TestCountAssistantMessages:
    @pytest.mark.asyncio
    async def test_returns_count(self, repo, mock_session):
        result_mock = MagicMock()
        result_mock.scalar.return_value = 5
        mock_session.execute.return_value = result_mock

        count = await repo.count_assistant_messages("s1")
        assert count == 5

    @pytest.mark.asyncio
    async def test_returns_zero(self, repo, mock_session):
        result_mock = MagicMock()
        result_mock.scalar.return_value = 0
        mock_session.execute.return_value = result_mock

        count = await repo.count_assistant_messages("s1")
        assert count == 0


class TestUsage:
    @pytest.mark.asyncio
    async def test_get_usage(self, repo, mock_session):
        result_mock = MagicMock()
        result_mock.one_or_none.return_value = (1, None)
        mock_session.execute.return_value = result_mock

        usage = await repo.get_usage(FAKE_USER_ID)
        assert usage["interview_usage_count"] == 1

    @pytest.mark.asyncio
    async def test_increment_usage(self, repo, mock_session):
        await repo.increment_usage(FAKE_USER_ID)
        mock_session.execute.assert_called_once()
        mock_session.flush.assert_called_once()
