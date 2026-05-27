"""Tests for api/dependencies.py — FastAPI dependency injection."""

from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from core.exceptions import InvalidToken
from tests.conftest import FAKE_USER_ID, _make_user_obj


class TestGetCurrentUser:

    async def _call_get_current_user(self, token="fake-token"):
        from api.v1.client.dependencies import get_current_user
        mock_session = AsyncMock()
        return await get_current_user(token=token, session=mock_session)

    @pytest.mark.asyncio
    async def test_valid_token_returns_user(self, fake_user_dict):
        with patch("api.v1.client.dependencies.Security") as MockSec, \
             patch("api.v1.client.dependencies.AuthRepository") as MockRepo:
            MockSec.decode_token.return_value = {"sub": FAKE_USER_ID, "type": "access"}
            mock_repo_instance = AsyncMock()
            mock_repo_instance.get_user_by_id.return_value = fake_user_dict
            MockRepo.return_value = mock_repo_instance

            result = await self._call_get_current_user("valid-token")
        assert result == fake_user_dict

    @pytest.mark.asyncio
    async def test_invalid_token_raises_401(self):
        with patch("api.v1.client.dependencies.Security") as MockSec:
            MockSec.decode_token.return_value = None
            with pytest.raises(InvalidToken) as exc_info:
                await self._call_get_current_user("bad-token")
        assert exc_info.value.status_code == 401

    @pytest.mark.asyncio
    async def test_refresh_token_type_raises_401(self):
        with patch("api.v1.client.dependencies.Security") as MockSec:
            MockSec.decode_token.return_value = {"sub": FAKE_USER_ID, "type": "refresh"}
            with pytest.raises(InvalidToken) as exc_info:
                await self._call_get_current_user("refresh-token")
        assert exc_info.value.status_code == 401

    @pytest.mark.asyncio
    async def test_user_not_found_raises_401(self):
        with patch("api.v1.client.dependencies.Security") as MockSec, \
             patch("api.v1.client.dependencies.AuthRepository") as MockRepo:
            MockSec.decode_token.return_value = {"sub": FAKE_USER_ID, "type": "access"}
            mock_repo_instance = AsyncMock()
            mock_repo_instance.get_user_by_id.return_value = None
            MockRepo.return_value = mock_repo_instance

            with pytest.raises(InvalidToken) as exc_info:
                await self._call_get_current_user("valid-token")
        assert exc_info.value.status_code == 401

    @pytest.mark.asyncio
    async def test_missing_type_raises_401(self):
        with patch("api.v1.client.dependencies.Security") as MockSec:
            MockSec.decode_token.return_value = {"sub": FAKE_USER_ID}
            with pytest.raises(InvalidToken) as exc_info:
                await self._call_get_current_user("no-type-token")
        assert exc_info.value.status_code == 401

    @pytest.mark.asyncio
    async def test_empty_sub_still_queries_repo(self, fake_user_dict):
        with patch("api.v1.client.dependencies.Security") as MockSec, \
             patch("api.v1.client.dependencies.AuthRepository") as MockRepo:
            MockSec.decode_token.return_value = {"sub": None, "type": "access"}
            mock_repo_instance = AsyncMock()
            mock_repo_instance.get_user_by_id.return_value = None
            MockRepo.return_value = mock_repo_instance

            with pytest.raises(InvalidToken) as exc_info:
                await self._call_get_current_user("valid-token")
        assert exc_info.value.status_code == 401

    @pytest.mark.asyncio
    async def test_decode_returns_no_sub_raises_401(self):
        with patch("api.v1.client.dependencies.Security") as MockSec, \
             patch("api.v1.client.dependencies.AuthRepository") as MockRepo:
            MockSec.decode_token.return_value = {"type": "access"}
            mock_repo_instance = AsyncMock()
            mock_repo_instance.get_user_by_id.return_value = None
            MockRepo.return_value = mock_repo_instance

            with pytest.raises(InvalidToken) as exc_info:
                await self._call_get_current_user("valid-token")
        assert exc_info.value.status_code == 401
