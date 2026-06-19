import uuid
import pytest

from datetime import datetime, timedelta, timezone
from unittest.mock import AsyncMock, MagicMock
from repositories.refresh_token_repository import RefreshTokenRepository
from models.db_models import RefreshToken
from tests.conftest import FAKE_USER_ID


@pytest.fixture
def mock_session():
    session = AsyncMock()
    return session


@pytest.fixture
def repo(mock_session):
    return RefreshTokenRepository(mock_session)


FAKE_TOKEN_HASH = "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2"
FAKE_EXPIRES_AT = datetime.now(timezone.utc) + timedelta(days=30)


class TestCreate:
    @pytest.mark.asyncio
    async def test_creates_and_flushes(self, repo, mock_session):
        result = await repo.create(FAKE_USER_ID, FAKE_TOKEN_HASH, FAKE_EXPIRES_AT)
        mock_session.add.assert_called_once()
        added_obj = mock_session.add.call_args[0][0]
        assert isinstance(added_obj, RefreshToken)
        assert added_obj.user_id == FAKE_USER_ID
        assert added_obj.token_hash == FAKE_TOKEN_HASH
        assert added_obj.expires_at == FAKE_EXPIRES_AT

        mock_session.flush.assert_called_once()

        assert result is added_obj


class TestGetByTokenHash:
    @pytest.mark.asyncio
    async def test_found(self, repo, mock_session):
        fake_token = MagicMock(spec=RefreshToken)
        fake_token.revoked = False
        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = fake_token
        mock_session.execute.return_value = mock_result

        result = await repo.get_by_token_hash(FAKE_TOKEN_HASH)

        assert result == fake_token
        mock_session.execute.assert_called_once()

    @pytest.mark.asyncio
    async def test_not_found(self, repo, mock_session):
        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = None
        mock_session.execute.return_value = mock_result

        result = await repo.get_by_token_hash("nonexistent-hash")
        assert result is None

    @pytest.mark.asyncio
    async def test_revoked_token_not_returned(self, repo, mock_session):
        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = None
        mock_session.execute.return_value = mock_result

        result = await repo.get_by_token_hash(FAKE_TOKEN_HASH)
        assert result is None


class TestRevoke:
    @pytest.mark.asyncio
    async def test_revokes_and_flushes(self, repo, mock_session):
        await repo.revoke(FAKE_TOKEN_HASH)

        mock_session.execute.assert_called_once()
        mock_session.flush.assert_called_once()

    @pytest.mark.asyncio
    async def test_revoke_nonexistent_no_error(self, repo, mock_session):
        await repo.revoke("nonexistent-hash")
        mock_session.execute.assert_called_once()


class TestRevokeAllForUser:
    @pytest.mark.asyncio
    async def test_revokes_all_and_flushes(self, repo, mock_session):
        await repo.revoke_all_for_user(FAKE_USER_ID)

        mock_session.execute.assert_called_once()
        mock_session.flush.assert_called_once()

    @pytest.mark.asyncio
    async def test_revoke_all_no_tokens_no_error(self, repo, mock_session):
        await repo.revoke_all_for_user("user-with-no-tokens")
        mock_session.execute.assert_called_once()
