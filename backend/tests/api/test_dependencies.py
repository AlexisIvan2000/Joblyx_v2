"""Tests for api/dependencies.py — FastAPI dependency injection."""

from unittest.mock import MagicMock, patch

import pytest
from fastapi import HTTPException

from tests.conftest import FAKE_USER_ID


class TestGetCurrentUser:

    def _call_get_current_user(self, token="fake-token"):
        from api.dependencies import get_current_user
        return get_current_user(token=token)

    def test_valid_token_returns_user(self, fake_user_dict):
        with patch("api.dependencies.Security") as MockSec, \
             patch("api.dependencies.AuthRepository") as MockRepo:
            MockSec.decode_token.return_value = {"sub": FAKE_USER_ID, "type": "access"}
            mock_repo_instance = MagicMock()
            mock_repo_instance.get_user_by_id.return_value = fake_user_dict
            MockRepo.return_value = mock_repo_instance

            result = self._call_get_current_user("valid-token")
        assert result == fake_user_dict

    def test_invalid_token_raises_401(self):
        with patch("api.dependencies.Security") as MockSec:
            MockSec.decode_token.return_value = None
            with pytest.raises(HTTPException) as exc_info:
                self._call_get_current_user("bad-token")
        assert exc_info.value.status_code == 401

    def test_refresh_token_type_raises_401(self):
        with patch("api.dependencies.Security") as MockSec:
            MockSec.decode_token.return_value = {"sub": FAKE_USER_ID, "type": "refresh"}
            with pytest.raises(HTTPException) as exc_info:
                self._call_get_current_user("refresh-token")
        assert exc_info.value.status_code == 401

    def test_user_not_found_raises_401(self):
        with patch("api.dependencies.Security") as MockSec, \
             patch("api.dependencies.AuthRepository") as MockRepo:
            MockSec.decode_token.return_value = {"sub": FAKE_USER_ID, "type": "access"}
            mock_repo_instance = MagicMock()
            mock_repo_instance.get_user_by_id.return_value = None
            MockRepo.return_value = mock_repo_instance

            with pytest.raises(HTTPException) as exc_info:
                self._call_get_current_user("valid-token")
        assert exc_info.value.status_code == 401

    def test_missing_type_raises_401(self):
        with patch("api.dependencies.Security") as MockSec:
            MockSec.decode_token.return_value = {"sub": FAKE_USER_ID}
            with pytest.raises(HTTPException) as exc_info:
                self._call_get_current_user("no-type-token")
        assert exc_info.value.status_code == 401

    def test_empty_sub_still_queries_repo(self, fake_user_dict):
        with patch("api.dependencies.Security") as MockSec, \
             patch("api.dependencies.AuthRepository") as MockRepo:
            MockSec.decode_token.return_value = {"sub": None, "type": "access"}
            mock_repo_instance = MagicMock()
            mock_repo_instance.get_user_by_id.return_value = None
            MockRepo.return_value = mock_repo_instance

            with pytest.raises(HTTPException) as exc_info:
                self._call_get_current_user("valid-token")
        assert exc_info.value.status_code == 401

    def test_decode_returns_no_sub_raises_401(self):
        with patch("api.dependencies.Security") as MockSec, \
             patch("api.dependencies.AuthRepository") as MockRepo:
            MockSec.decode_token.return_value = {"type": "access"}
            mock_repo_instance = MagicMock()
            mock_repo_instance.get_user_by_id.return_value = None
            MockRepo.return_value = mock_repo_instance

            with pytest.raises(HTTPException) as exc_info:
                self._call_get_current_user("valid-token")
        assert exc_info.value.status_code == 401
