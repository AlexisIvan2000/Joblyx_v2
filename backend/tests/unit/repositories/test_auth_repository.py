import uuid
import pytest

from unittest.mock import AsyncMock, MagicMock, patch
from repositories.auth_repository import AuthRepository
from models.db_models import User
from tests.conftest import _make_user_obj, FAKE_USER_ID


@pytest.fixture
def mock_session():
    session = AsyncMock()
    return session


@pytest.fixture
def repo(mock_session):
    return AuthRepository(mock_session)


class TestGetUserByEmail:
    @pytest.mark.asyncio
    async def test_found(self, repo, mock_session, fake_user_dict):
        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = fake_user_dict
        mock_session.execute.return_value = mock_result

        result = await repo.get_user_by_email("john@example.com")
        assert result == fake_user_dict
        mock_session.execute.assert_called_once()

    @pytest.mark.asyncio
    async def test_not_found(self, repo, mock_session):
        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = None
        mock_session.execute.return_value = mock_result

        result = await repo.get_user_by_email("nope@example.com")
        assert result is None


class TestGetUserById:
    @pytest.mark.asyncio
    async def test_found(self, repo, mock_session, fake_user_dict):
        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = fake_user_dict
        mock_session.execute.return_value = mock_result

        result = await repo.get_user_by_id(FAKE_USER_ID)
        assert result == fake_user_dict

    @pytest.mark.asyncio
    async def test_not_found(self, repo, mock_session):
        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = None
        mock_session.execute.return_value = mock_result

        result = await repo.get_user_by_id("nonexistent")
        assert result is None


class TestCreateUser:
    @pytest.mark.asyncio
    async def test_returns_created_user(self, repo, mock_session):
        result = await repo.create_user({"email": "john@example.com", "first_name": "John", "last_name": "Doe", "password_hash": "hashed"})
        mock_session.add.assert_called_once()
        mock_session.flush.assert_called_once()
        assert isinstance(result, User)


class TestUpdateUser:
    @pytest.mark.asyncio
    async def test_calls_update(self, repo, mock_session, fake_user_dict):
        mock_result = MagicMock()
        mock_result.scalar_one.return_value = fake_user_dict
        mock_session.execute.return_value = mock_result

        await repo.update_user(FAKE_USER_ID, {"first_name": "Jane"})
        assert mock_session.execute.call_count == 2  # update + select
        mock_session.flush.assert_called_once()


class TestUpdateVerificationStatus:
    @pytest.mark.asyncio
    async def test_clears_verification_fields(self, repo, mock_session, fake_user_dict):
        mock_result = MagicMock()
        mock_result.scalar_one.return_value = fake_user_dict
        mock_session.execute.return_value = mock_result

        await repo.update_verification_status(FAKE_USER_ID)
        assert mock_session.execute.call_count == 2
        mock_session.flush.assert_called_once()


class TestSaveResetCode:
    @pytest.mark.asyncio
    async def test_saves_code(self, repo, mock_session, fake_user_dict):
        mock_result = MagicMock()
        mock_result.scalar_one.return_value = fake_user_dict
        mock_session.execute.return_value = mock_result

        await repo.save_reset_code("john@example.com", "hash123", "2026-01-01T00:00:00Z")
        assert mock_session.execute.call_count == 2  # update + select
        mock_session.flush.assert_called_once()


class TestIncrementVerificationAttempts:
    @pytest.mark.asyncio
    async def test_increments(self, repo, mock_session):
        await repo.increment_verification_attempts(FAKE_USER_ID)
        mock_session.execute.assert_called_once()
        mock_session.flush.assert_called_once()


class TestResetVerificationAttempts:
    @pytest.mark.asyncio
    async def test_resets(self, repo, mock_session):
        await repo.reset_verification_attempts(FAKE_USER_ID)
        mock_session.execute.assert_called_once()
        mock_session.flush.assert_called_once()
