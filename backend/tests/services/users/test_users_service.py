"""Tests for services/users/users.py — user profile operations."""

from datetime import datetime, timedelta, timezone
from unittest.mock import MagicMock, patch

import pytest
from fastapi import HTTPException

from models.schemas import UpdateProfile
from services.users.users import UserService
from tests.conftest import FAKE_USER_ID


@pytest.fixture
def user_service(mock_auth_repo):
    return UserService(mock_auth_repo)


# ─── update_profile ──────────────────────────────────────────────────

class TestUpdateProfile:
    def test_success(self, user_service, mock_auth_repo):
        data = UpdateProfile(first_name="Jane")
        result = user_service.update_profile(FAKE_USER_ID, data)
        assert "updated" in result["message"].lower()
        mock_auth_repo.update_user.assert_called_once()

    def test_empty_data_raises_400(self, user_service):
        data = UpdateProfile()
        with pytest.raises(HTTPException) as exc_info:
            user_service.update_profile(FAKE_USER_ID, data)
        assert exc_info.value.status_code == 400


# ─── change_password ─────────────────────────────────────────────────

class TestChangePassword:
    def test_success(self, user_service, mock_auth_repo, fake_user_dict):
        mock_auth_repo.get_user_by_id.return_value = fake_user_dict
        with patch("services.users.users.Security") as MockSec:
            MockSec.verify_password.return_value = True
            MockSec.hash_password.return_value = "new-hash"
            result = user_service.change_password(FAKE_USER_ID, "OldPass1!", "NewPass1!")
        assert "changed" in result["message"].lower()

    def test_wrong_current_password_raises_401(self, user_service, mock_auth_repo, fake_user_dict):
        mock_auth_repo.get_user_by_id.return_value = fake_user_dict
        with patch("services.users.users.Security") as MockSec:
            MockSec.verify_password.return_value = False
            with pytest.raises(HTTPException) as exc_info:
                user_service.change_password(FAKE_USER_ID, "wrong", "NewPass1!")
        assert exc_info.value.status_code == 401


# ─── forgot_password ─────────────────────────────────────────────────

class TestForgotPassword:
    def test_sends_if_user_exists(self, user_service, mock_auth_repo, fake_user_dict):
        mock_auth_repo.get_user_by_email.return_value = fake_user_dict
        with patch("services.users.users.EmailSender") as MockEmail:
            MockEmail.return_value = MagicMock()
            result = user_service.forgot_password("john@example.com")
        assert "message" in result
        mock_auth_repo.save_reset_token.assert_called_once()
        MockEmail.return_value.send_reset_password_email.assert_called_once()

    def test_no_send_if_not_found(self, user_service, mock_auth_repo):
        mock_auth_repo.get_user_by_email.return_value = None
        result = user_service.forgot_password("nope@example.com")
        assert "message" in result
        mock_auth_repo.save_reset_token.assert_not_called()

    def test_generic_message_always(self, user_service, mock_auth_repo):
        mock_auth_repo.get_user_by_email.return_value = None
        result = user_service.forgot_password("nope@example.com")
        assert "if" in result["message"].lower() or "reset" in result["message"].lower()


# ─── reset_password ──────────────────────────────────────────────────

class TestResetPassword:
    def test_success(self, user_service, mock_auth_repo, fake_user_with_reset_token):
        mock_auth_repo.get_user_by_reset_token.return_value = fake_user_with_reset_token
        with patch("services.users.users.Security") as MockSec:
            MockSec.hash_password.return_value = "new-hash"
            result = user_service.reset_password("reset-token-789", "NewPass1!")
        assert "reset" in result["message"].lower()
        mock_auth_repo.update_password.assert_called_once()

    def test_invalid_token_raises_400(self, user_service, mock_auth_repo):
        mock_auth_repo.get_user_by_reset_token.return_value = None
        with pytest.raises(HTTPException) as exc_info:
            user_service.reset_password("bad-token", "NewPass1!")
        assert exc_info.value.status_code == 400

    def test_expired_token_raises_400(self, user_service, mock_auth_repo, fake_user_with_expired_reset_token):
        mock_auth_repo.get_user_by_reset_token.return_value = fake_user_with_expired_reset_token
        with pytest.raises(HTTPException) as exc_info:
            user_service.reset_password("expired-reset-token", "NewPass1!")
        assert exc_info.value.status_code == 400


# ─── confirm_email_change ─────────────────────────────────────────────

class TestConfirmEmailChange:
    def test_success(self, user_service, mock_auth_repo, fake_user_with_pending_email):
        mock_auth_repo.get_user_by_verification_token.return_value = fake_user_with_pending_email
        result = user_service.confirm_email_change("email-change-token-456")
        assert "changed" in result["message"].lower()
        mock_auth_repo.update_user.assert_called_once()
        call_data = mock_auth_repo.update_user.call_args[0][1]
        assert call_data["email"] == "newemail@example.com"
        assert call_data["pending_email"] is None
        assert call_data["verification_token"] is None

    def test_invalid_token_raises_400(self, user_service, mock_auth_repo):
        mock_auth_repo.get_user_by_verification_token.return_value = None
        with pytest.raises(HTTPException) as exc_info:
            user_service.confirm_email_change("bad-token")
        assert exc_info.value.status_code == 400

    def test_expired_token_raises_400(self, user_service, mock_auth_repo, fake_user_with_pending_email):
        expired = {
            **fake_user_with_pending_email,
            "verification_token_expires_at": (
                datetime.now(timezone.utc) - timedelta(hours=1)
            ).isoformat(),
        }
        mock_auth_repo.get_user_by_verification_token.return_value = expired
        with pytest.raises(HTTPException) as exc_info:
            user_service.confirm_email_change("email-change-token-456")
        assert exc_info.value.status_code == 400

    def test_no_pending_email_raises_400(self, user_service, mock_auth_repo, fake_unverified_user_dict):
        mock_auth_repo.get_user_by_verification_token.return_value = fake_unverified_user_dict
        with pytest.raises(HTTPException) as exc_info:
            user_service.confirm_email_change("verify-token-123")
        assert exc_info.value.status_code == 400


# ─── request_email_change ────────────────────────────────────────────

class TestRequestEmailChange:
    def test_success(self, user_service, mock_auth_repo, fake_user_dict):
        mock_auth_repo.get_user_by_id.return_value = fake_user_dict
        mock_auth_repo.get_user_by_email.return_value = None
        with patch("services.users.users.Security") as MockSec, \
             patch("services.users.users.EmailSender") as MockEmail:
            MockSec.verify_password.return_value = True
            MockEmail.return_value = MagicMock()
            result = user_service.request_email_change(FAKE_USER_ID, "new@example.com", "Secure1!x")
        assert "verification" in result["message"].lower() or "sent" in result["message"].lower()
        MockEmail.return_value.send_verification_email.assert_called_once()

    def test_wrong_password_raises_401(self, user_service, mock_auth_repo, fake_user_dict):
        mock_auth_repo.get_user_by_id.return_value = fake_user_dict
        with patch("services.users.users.Security") as MockSec:
            MockSec.verify_password.return_value = False
            with pytest.raises(HTTPException) as exc_info:
                user_service.request_email_change(FAKE_USER_ID, "new@example.com", "wrong")
        assert exc_info.value.status_code == 401

    def test_email_taken_raises_400(self, user_service, mock_auth_repo, fake_user_dict):
        mock_auth_repo.get_user_by_id.return_value = fake_user_dict
        mock_auth_repo.get_user_by_email.return_value = {"id": "other-user"}
        with patch("services.users.users.Security") as MockSec:
            MockSec.verify_password.return_value = True
            with pytest.raises(HTTPException) as exc_info:
                user_service.request_email_change(FAKE_USER_ID, "taken@example.com", "Secure1!x")
        assert exc_info.value.status_code == 400
