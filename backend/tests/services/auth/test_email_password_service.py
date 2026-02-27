"""Tests for services/auth/email_password.py — business logic."""

from datetime import datetime, timedelta, timezone
from unittest.mock import MagicMock, patch

import pytest
from fastapi import HTTPException

from models.schemas import UserCreate, UserLogin, UpdateProfile
from tests.conftest import FAKE_USER_ID


# ─── register_user ────────────────────────────────────────────────────

class TestRegisterUser:
    def test_success_returns_tokens(self, auth_service, mock_auth_repo):
        with patch("services.auth.email_password.Security") as MockSec:
            MockSec.hash_password.return_value = "hashed"
            MockSec.create_access_token.return_value = "access-tok"
            MockSec.create_refresh_token.return_value = "refresh-tok"

            user = UserCreate(
                first_name="John",
                last_name="Doe",
                email="john@example.com",
                password="Secure1!x",
            )
            result = auth_service.register_user(user)

        assert result["access_token"] == "access-tok"
        assert result["refresh_token"] == "refresh-tok"
        assert result["token_type"] == "bearer"

    def test_email_already_taken_raises_400(self, auth_service, mock_auth_repo, fake_user_dict):
        mock_auth_repo.get_user_by_email.return_value = fake_user_dict
        user = UserCreate(
            first_name="John",
            last_name="Doe",
            email="john@example.com",
            password="Secure1!x",
        )
        with pytest.raises(HTTPException) as exc_info:
            auth_service.register_user(user)
        assert exc_info.value.status_code == 400

    def test_calls_hash_password(self, auth_service, mock_auth_repo):
        with patch("services.auth.email_password.Security") as MockSec:
            MockSec.hash_password.return_value = "hashed"
            MockSec.create_access_token.return_value = "at"
            MockSec.create_refresh_token.return_value = "rt"

            user = UserCreate(
                first_name="A", last_name="B",
                email="a@b.com", password="Secure1!x",
            )
            auth_service.register_user(user)

        MockSec.hash_password.assert_called_once_with("Secure1!x")

    def test_calls_create_user(self, auth_service, mock_auth_repo):
        with patch("services.auth.email_password.Security") as MockSec:
            MockSec.hash_password.return_value = "hashed"
            MockSec.create_access_token.return_value = "at"
            MockSec.create_refresh_token.return_value = "rt"

            user = UserCreate(
                first_name="A", last_name="B",
                email="a@b.com", password="Secure1!x",
            )
            auth_service.register_user(user)

        mock_auth_repo.create_user.assert_called_once()
        call_data = mock_auth_repo.create_user.call_args[0][0]
        assert call_data["email"] == "a@b.com"
        assert call_data["password_hash"] == "hashed"

    def test_sends_verification_email(self, auth_service, mock_auth_repo):
        with patch("services.auth.email_password.Security") as MockSec:
            MockSec.hash_password.return_value = "hashed"
            MockSec.create_access_token.return_value = "at"
            MockSec.create_refresh_token.return_value = "rt"

            user = UserCreate(
                first_name="A", last_name="B",
                email="a@b.com", password="Secure1!x",
            )
            auth_service.register_user(user)

        auth_service._mock_email_sender.return_value.send_verification_email.assert_called_once()


# ─── login_user ──────────────────────────────────────────────────────

class TestLoginUser:
    def test_success_returns_tokens(self, auth_service, mock_auth_repo, fake_user_dict):
        mock_auth_repo.get_user_by_email.return_value = fake_user_dict
        with patch("services.auth.email_password.Security") as MockSec:
            MockSec.verify_password.return_value = True
            MockSec.create_access_token.return_value = "access-tok"
            MockSec.create_refresh_token.return_value = "refresh-tok"

            user = UserLogin(email="john@example.com", password="Secure1!x")
            result = auth_service.login_user(user)

        assert result["access_token"] == "access-tok"
        assert result["refresh_token"] == "refresh-tok"

    def test_unknown_email_raises_401(self, auth_service, mock_auth_repo):
        mock_auth_repo.get_user_by_email.return_value = None
        user = UserLogin(email="unknown@example.com", password="pass")
        with pytest.raises(HTTPException) as exc_info:
            auth_service.login_user(user)
        assert exc_info.value.status_code == 401

    def test_wrong_password_raises_401(self, auth_service, mock_auth_repo, fake_user_dict):
        mock_auth_repo.get_user_by_email.return_value = fake_user_dict
        with patch("services.auth.email_password.Security") as MockSec:
            MockSec.verify_password.return_value = False
            user = UserLogin(email="john@example.com", password="wrong")
            with pytest.raises(HTTPException) as exc_info:
                auth_service.login_user(user)
        assert exc_info.value.status_code == 401

    def test_unverified_user_raises_403(self, auth_service, mock_auth_repo, fake_unverified_user_dict):
        mock_auth_repo.get_user_by_email.return_value = fake_unverified_user_dict
        with patch("services.auth.email_password.Security") as MockSec:
            MockSec.verify_password.return_value = True
            user = UserLogin(email="john@example.com", password="Secure1!x")
            with pytest.raises(HTTPException) as exc_info:
                auth_service.login_user(user)
        assert exc_info.value.status_code == 403


# ─── verify_email ────────────────────────────────────────────────────

class TestVerifyEmail:
    def test_success(self, auth_service, mock_auth_repo, fake_unverified_user_dict):
        mock_auth_repo.get_user_by_verification_token.return_value = fake_unverified_user_dict
        result = auth_service.verify_email("verify-token-123")
        assert "verified" in result["message"].lower()
        mock_auth_repo.update_verification_status.assert_called_once()

    def test_invalid_token_raises_400(self, auth_service, mock_auth_repo):
        mock_auth_repo.get_user_by_verification_token.return_value = None
        with pytest.raises(HTTPException) as exc_info:
            auth_service.verify_email("bad-token")
        assert exc_info.value.status_code == 400

    def test_expired_token_raises_400(self, auth_service, mock_auth_repo, fake_unverified_user_dict):
        expired = {
            **fake_unverified_user_dict,
            "verification_token_expires_at": (
                datetime.now(timezone.utc) - timedelta(hours=1)
            ).isoformat(),
        }
        mock_auth_repo.get_user_by_verification_token.return_value = expired
        with pytest.raises(HTTPException) as exc_info:
            auth_service.verify_email("verify-token-123")
        assert exc_info.value.status_code == 400

    def test_pending_email_flow(self, auth_service, mock_auth_repo, fake_user_with_pending_email):
        mock_auth_repo.get_user_by_verification_token.return_value = fake_user_with_pending_email
        result = auth_service.verify_email("email-change-token-456")
        assert "changed" in result["message"].lower() or "verified" in result["message"].lower()
        # Should update email, not just verification status
        mock_auth_repo.update_user.assert_called()
        call_data = mock_auth_repo.update_user.call_args[0][1]
        assert call_data["email"] == "newemail@example.com"
        assert call_data["pending_email"] is None


# ─── resend_verification_email ────────────────────────────────────────

class TestResendVerificationEmail:
    def test_sends_if_unverified(self, auth_service, mock_auth_repo, fake_unverified_user_dict):
        mock_auth_repo.get_user_by_email.return_value = fake_unverified_user_dict
        result = auth_service.resend_verification_email("john@example.com")
        assert "message" in result
        auth_service._mock_email_sender.return_value.send_verification_email.assert_called_once()

    def test_no_send_if_verified(self, auth_service, mock_auth_repo, fake_user_dict):
        mock_auth_repo.get_user_by_email.return_value = fake_user_dict
        result = auth_service.resend_verification_email("john@example.com")
        assert "message" in result
        auth_service._mock_email_sender.return_value.send_verification_email.assert_not_called()

    def test_generic_message_if_not_found(self, auth_service, mock_auth_repo):
        mock_auth_repo.get_user_by_email.return_value = None
        result = auth_service.resend_verification_email("nope@example.com")
        assert "message" in result


# ─── resend_email_change_verification ─────────────────────────────────

class TestResendEmailChangeVerification:
    def test_success_if_pending_email(self, auth_service, mock_auth_repo, fake_user_with_pending_email):
        mock_auth_repo.get_user_by_id.return_value = fake_user_with_pending_email
        result = auth_service.resend_email_change_verification(FAKE_USER_ID)
        assert "resent" in result["message"].lower()
        auth_service._mock_email_sender.return_value.send_verification_email.assert_called_once()

    def test_raises_400_if_no_pending(self, auth_service, mock_auth_repo, fake_user_dict):
        mock_auth_repo.get_user_by_id.return_value = fake_user_dict
        with pytest.raises(HTTPException) as exc_info:
            auth_service.resend_email_change_verification(FAKE_USER_ID)
        assert exc_info.value.status_code == 400


# ─── refresh_access_token ────────────────────────────────────────────

class TestRefreshAccessToken:
    def test_success(self, auth_service):
        with patch("services.auth.email_password.Security") as MockSec:
            MockSec.decode_token.return_value = {"sub": FAKE_USER_ID, "type": "refresh"}
            MockSec.create_access_token.return_value = "new-access-tok"
            result = auth_service.refresh_access_token("valid-refresh")
        assert result["access_token"] == "new-access-tok"

    def test_invalid_token_raises_401(self, auth_service):
        with patch("services.auth.email_password.Security") as MockSec:
            MockSec.decode_token.return_value = None
            with pytest.raises(HTTPException) as exc_info:
                auth_service.refresh_access_token("garbage")
        assert exc_info.value.status_code == 401

    def test_access_type_raises_401(self, auth_service):
        with patch("services.auth.email_password.Security") as MockSec:
            MockSec.decode_token.return_value = {"sub": FAKE_USER_ID, "type": "access"}
            with pytest.raises(HTTPException) as exc_info:
                auth_service.refresh_access_token("access-token-instead")
        assert exc_info.value.status_code == 401


# ─── update_profile ──────────────────────────────────────────────────

class TestUpdateProfile:
    def test_success(self, auth_service, mock_auth_repo):
        data = UpdateProfile(first_name="Jane")
        result = auth_service.update_profile(FAKE_USER_ID, data)
        assert "updated" in result["message"].lower()
        mock_auth_repo.update_user.assert_called_once()

    def test_empty_data_raises_400(self, auth_service):
        data = UpdateProfile()
        with pytest.raises(HTTPException) as exc_info:
            auth_service.update_profile(FAKE_USER_ID, data)
        assert exc_info.value.status_code == 400


# ─── change_password ─────────────────────────────────────────────────

class TestChangePassword:
    def test_success(self, auth_service, mock_auth_repo, fake_user_dict):
        mock_auth_repo.get_user_by_id.return_value = fake_user_dict
        with patch("services.auth.email_password.Security") as MockSec:
            MockSec.verify_password.return_value = True
            MockSec.hash_password.return_value = "new-hash"
            result = auth_service.change_password(FAKE_USER_ID, "OldPass1!", "NewPass1!")
        assert "changed" in result["message"].lower()

    def test_wrong_current_password_raises_401(self, auth_service, mock_auth_repo, fake_user_dict):
        mock_auth_repo.get_user_by_id.return_value = fake_user_dict
        with patch("services.auth.email_password.Security") as MockSec:
            MockSec.verify_password.return_value = False
            with pytest.raises(HTTPException) as exc_info:
                auth_service.change_password(FAKE_USER_ID, "wrong", "NewPass1!")
        assert exc_info.value.status_code == 401


# ─── forgot_password ─────────────────────────────────────────────────

class TestForgotPassword:
    def test_sends_if_user_exists(self, auth_service, mock_auth_repo, fake_user_dict):
        mock_auth_repo.get_user_by_email.return_value = fake_user_dict
        result = auth_service.forgot_password("john@example.com")
        assert "message" in result
        mock_auth_repo.save_reset_token.assert_called_once()
        auth_service._mock_email_sender.return_value.send_reset_password_email.assert_called_once()

    def test_no_send_if_not_found(self, auth_service, mock_auth_repo):
        mock_auth_repo.get_user_by_email.return_value = None
        result = auth_service.forgot_password("nope@example.com")
        assert "message" in result
        mock_auth_repo.save_reset_token.assert_not_called()

    def test_generic_message_always(self, auth_service, mock_auth_repo):
        mock_auth_repo.get_user_by_email.return_value = None
        result = auth_service.forgot_password("nope@example.com")
        # Should not reveal whether user exists
        assert "if" in result["message"].lower() or "reset" in result["message"].lower()


# ─── reset_password ──────────────────────────────────────────────────

class TestResetPassword:
    def test_success(self, auth_service, mock_auth_repo, fake_user_with_reset_token):
        mock_auth_repo.get_user_by_reset_token.return_value = fake_user_with_reset_token
        with patch("services.auth.email_password.Security") as MockSec:
            MockSec.hash_password.return_value = "new-hash"
            result = auth_service.reset_password("reset-token-789", "NewPass1!")
        assert "reset" in result["message"].lower()
        mock_auth_repo.update_password.assert_called_once()

    def test_invalid_token_raises_400(self, auth_service, mock_auth_repo):
        mock_auth_repo.get_user_by_reset_token.return_value = None
        with pytest.raises(HTTPException) as exc_info:
            auth_service.reset_password("bad-token", "NewPass1!")
        assert exc_info.value.status_code == 400

    def test_expired_token_raises_400(self, auth_service, mock_auth_repo, fake_user_with_expired_reset_token):
        mock_auth_repo.get_user_by_reset_token.return_value = fake_user_with_expired_reset_token
        with pytest.raises(HTTPException) as exc_info:
            auth_service.reset_password("expired-reset-token", "NewPass1!")
        assert exc_info.value.status_code == 400


# ─── request_email_change ────────────────────────────────────────────

class TestRequestEmailChange:
    def test_success(self, auth_service, mock_auth_repo, fake_user_dict):
        mock_auth_repo.get_user_by_id.return_value = fake_user_dict
        mock_auth_repo.get_user_by_email.return_value = None  # new email not taken
        with patch("services.auth.email_password.Security") as MockSec:
            MockSec.verify_password.return_value = True
            result = auth_service.request_email_change(FAKE_USER_ID, "new@example.com", "Secure1!x")
        assert "verification" in result["message"].lower() or "sent" in result["message"].lower()
        auth_service._mock_email_sender.return_value.send_verification_email.assert_called_once()

    def test_wrong_password_raises_401(self, auth_service, mock_auth_repo, fake_user_dict):
        mock_auth_repo.get_user_by_id.return_value = fake_user_dict
        with patch("services.auth.email_password.Security") as MockSec:
            MockSec.verify_password.return_value = False
            with pytest.raises(HTTPException) as exc_info:
                auth_service.request_email_change(FAKE_USER_ID, "new@example.com", "wrong")
        assert exc_info.value.status_code == 401

    def test_email_taken_raises_400(self, auth_service, mock_auth_repo, fake_user_dict):
        mock_auth_repo.get_user_by_id.return_value = fake_user_dict
        mock_auth_repo.get_user_by_email.return_value = {"id": "other-user"}
        with patch("services.auth.email_password.Security") as MockSec:
            MockSec.verify_password.return_value = True
            with pytest.raises(HTTPException) as exc_info:
                auth_service.request_email_change(FAKE_USER_ID, "taken@example.com", "Secure1!x")
        assert exc_info.value.status_code == 400
