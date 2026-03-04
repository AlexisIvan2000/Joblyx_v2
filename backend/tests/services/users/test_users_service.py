"""Tests for services/users/users.py — user profile operations."""

from datetime import datetime, timedelta, timezone
from unittest.mock import MagicMock, patch

import pytest
from fastapi import HTTPException

from models.schemas import UpdateProfile
from services.users.users import UserService
from tests.conftest import FAKE_USER_ID, FAKE_OTP_CODE, FAKE_OTP_HASH, _make_user_obj


@pytest.fixture
def user_service(mock_auth_repo, mock_otp_service):
    return UserService(mock_auth_repo, mock_otp_service)


# ─── update_profile ──────────────────────────────────────────────────

class TestUpdateProfile:
    @pytest.mark.asyncio
    async def test_success(self, user_service, mock_auth_repo):
        data = UpdateProfile(first_name="Jane")
        result = await user_service.update_profile(FAKE_USER_ID, data)
        assert "updated" in result["message"].lower()
        mock_auth_repo.update_user.assert_called_once()

    @pytest.mark.asyncio
    async def test_empty_data_raises_400(self, user_service):
        data = UpdateProfile()
        with pytest.raises(HTTPException) as exc_info:
            await user_service.update_profile(FAKE_USER_ID, data)
        assert exc_info.value.status_code == 400


# ─── change_password ─────────────────────────────────────────────────

class TestChangePassword:
    @pytest.mark.asyncio
    async def test_success(self, user_service, mock_auth_repo, fake_user_dict):
        mock_auth_repo.get_user_by_id.return_value = fake_user_dict
        with patch("services.users.users.Security") as MockSec:
            MockSec.verify_password.return_value = True
            MockSec.hash_password.return_value = "new-hash"
            result = await user_service.change_password(FAKE_USER_ID, "OldPass1!", "NewPass1!")
        assert "changed" in result["message"].lower()

    @pytest.mark.asyncio
    async def test_wrong_current_password_raises_401(self, user_service, mock_auth_repo, fake_user_dict):
        mock_auth_repo.get_user_by_id.return_value = fake_user_dict
        with patch("services.users.users.Security") as MockSec:
            MockSec.verify_password.return_value = False
            with pytest.raises(HTTPException) as exc_info:
                await user_service.change_password(FAKE_USER_ID, "wrong", "NewPass1!")
        assert exc_info.value.status_code == 401


# ─── forgot_password ─────────────────────────────────────────────────

class TestForgotPassword:
    @pytest.mark.asyncio
    async def test_sends_if_user_exists(self, user_service, mock_auth_repo, mock_otp_service, fake_user_dict):
        mock_auth_repo.get_user_by_email.return_value = fake_user_dict
        result = await user_service.forgot_password("john@example.com")
        assert "message" in result
        mock_otp_service.send_reset_otp.assert_called_once_with("john@example.com")

    @pytest.mark.asyncio
    async def test_no_send_if_not_found(self, user_service, mock_auth_repo, mock_otp_service):
        mock_auth_repo.get_user_by_email.return_value = None
        result = await user_service.forgot_password("nope@example.com")
        assert "message" in result
        mock_otp_service.send_reset_otp.assert_not_called()

    @pytest.mark.asyncio
    async def test_generic_message_always(self, user_service, mock_auth_repo):
        mock_auth_repo.get_user_by_email.return_value = None
        result = await user_service.forgot_password("nope@example.com")
        assert "if" in result["message"].lower() or "reset" in result["message"].lower()


# ─── reset_password ──────────────────────────────────────────────────

class TestResetPassword:
    @pytest.mark.asyncio
    async def test_success(self, user_service, mock_auth_repo, fake_user_with_reset_code):
        mock_auth_repo.get_user_by_email.return_value = fake_user_with_reset_code
        with patch("services.users.users.Security") as MockSec:
            MockSec.hash_token.return_value = FAKE_OTP_HASH
            MockSec.hash_password.return_value = "new-hash"
            result = await user_service.reset_password("john@example.com", FAKE_OTP_CODE, "NewPass1!")
        assert "reset" in result["message"].lower()
        mock_auth_repo.update_password.assert_called_once()

    @pytest.mark.asyncio
    async def test_no_user_raises_400(self, user_service, mock_auth_repo):
        mock_auth_repo.get_user_by_email.return_value = None
        with pytest.raises(HTTPException) as exc_info:
            await user_service.reset_password("bad@example.com", "123456", "NewPass1!")
        assert exc_info.value.status_code == 400

    @pytest.mark.asyncio
    async def test_invalid_code_raises_400(self, user_service, mock_auth_repo, fake_user_with_reset_code):
        mock_auth_repo.get_user_by_email.return_value = fake_user_with_reset_code
        with patch("services.users.users.Security") as MockSec:
            MockSec.hash_token.return_value = "wrong-hash"
            with pytest.raises(HTTPException) as exc_info:
                await user_service.reset_password("john@example.com", "000000", "NewPass1!")
        assert exc_info.value.status_code == 400

    @pytest.mark.asyncio
    async def test_expired_code_raises_400(self, user_service, mock_auth_repo, fake_user_with_expired_reset_code):
        mock_auth_repo.get_user_by_email.return_value = fake_user_with_expired_reset_code
        with patch("services.users.users.Security") as MockSec:
            MockSec.hash_token.return_value = FAKE_OTP_HASH
            with pytest.raises(HTTPException) as exc_info:
                await user_service.reset_password("john@example.com", FAKE_OTP_CODE, "NewPass1!")
        assert exc_info.value.status_code == 400

    @pytest.mark.asyncio
    async def test_brute_force_5_attempts_raises_429(self, user_service, mock_auth_repo):
        maxed_out = _make_user_obj(
            reset_code_hash=FAKE_OTP_HASH,
            reset_code_expires_at=datetime.now(timezone.utc) + timedelta(minutes=15),
            verification_attempts=5,
        )
        mock_auth_repo.get_user_by_email.return_value = maxed_out
        with pytest.raises(HTTPException) as exc_info:
            await user_service.reset_password("john@example.com", FAKE_OTP_CODE, "NewPass1!")
        assert exc_info.value.status_code == 429


# ─── confirm_email_change ─────────────────────────────────────────────

class TestConfirmEmailChange:
    @pytest.mark.asyncio
    async def test_success(self, user_service, mock_auth_repo, fake_user_with_pending_email):
        mock_auth_repo.get_user_by_id.return_value = fake_user_with_pending_email
        with patch("services.users.users.Security") as MockSec:
            MockSec.hash_token.return_value = FAKE_OTP_HASH
            result = await user_service.confirm_email_change(FAKE_USER_ID, FAKE_OTP_CODE)
        assert "changed" in result["message"].lower()
        mock_auth_repo.update_user.assert_called()
        # Find the confirm call (not the pending_email set)
        last_call_data = mock_auth_repo.update_user.call_args[0][1]
        assert last_call_data["email"] == "newemail@example.com"
        assert last_call_data["pending_email"] is None
        assert last_call_data["email_change_code_hash"] is None

    @pytest.mark.asyncio
    async def test_no_pending_email_raises_400(self, user_service, mock_auth_repo, fake_user_dict):
        mock_auth_repo.get_user_by_id.return_value = fake_user_dict
        with pytest.raises(HTTPException) as exc_info:
            await user_service.confirm_email_change(FAKE_USER_ID, FAKE_OTP_CODE)
        assert exc_info.value.status_code == 400

    @pytest.mark.asyncio
    async def test_invalid_code_raises_400(self, user_service, mock_auth_repo, fake_user_with_pending_email):
        mock_auth_repo.get_user_by_id.return_value = fake_user_with_pending_email
        with patch("services.users.users.Security") as MockSec:
            MockSec.hash_token.return_value = "wrong-hash"
            with pytest.raises(HTTPException) as exc_info:
                await user_service.confirm_email_change(FAKE_USER_ID, "000000")
        assert exc_info.value.status_code == 400

    @pytest.mark.asyncio
    async def test_expired_code_raises_400(self, user_service, mock_auth_repo):
        expired = _make_user_obj(
            pending_email="newemail@example.com",
            email_change_code_hash=FAKE_OTP_HASH,
            email_change_code_expires_at=datetime.now(timezone.utc) - timedelta(hours=1),
            verification_attempts=0,
        )
        mock_auth_repo.get_user_by_id.return_value = expired
        with patch("services.users.users.Security") as MockSec:
            MockSec.hash_token.return_value = FAKE_OTP_HASH
            with pytest.raises(HTTPException) as exc_info:
                await user_service.confirm_email_change(FAKE_USER_ID, FAKE_OTP_CODE)
        assert exc_info.value.status_code == 400

    @pytest.mark.asyncio
    async def test_brute_force_5_attempts_raises_429(self, user_service, mock_auth_repo):
        maxed_out = _make_user_obj(
            pending_email="newemail@example.com",
            email_change_code_hash=FAKE_OTP_HASH,
            email_change_code_expires_at=datetime.now(timezone.utc) + timedelta(minutes=15),
            verification_attempts=5,
        )
        mock_auth_repo.get_user_by_id.return_value = maxed_out
        with pytest.raises(HTTPException) as exc_info:
            await user_service.confirm_email_change(FAKE_USER_ID, FAKE_OTP_CODE)
        assert exc_info.value.status_code == 429


# ─── request_email_change ────────────────────────────────────────────

class TestRequestEmailChange:
    @pytest.mark.asyncio
    async def test_success(self, user_service, mock_auth_repo, mock_otp_service, fake_user_dict):
        mock_auth_repo.get_user_by_id.return_value = fake_user_dict
        mock_auth_repo.get_user_by_email.return_value = None
        with patch("services.users.users.Security") as MockSec:
            MockSec.verify_password.return_value = True
            result = await user_service.request_email_change(FAKE_USER_ID, "new@example.com", "Secure1!x")
        assert "verification" in result["message"].lower() or "sent" in result["message"].lower()
        mock_otp_service.send_email_change_otp.assert_called_once_with("new@example.com", FAKE_USER_ID)

    @pytest.mark.asyncio
    async def test_wrong_password_raises_401(self, user_service, mock_auth_repo, fake_user_dict):
        mock_auth_repo.get_user_by_id.return_value = fake_user_dict
        with patch("services.users.users.Security") as MockSec:
            MockSec.verify_password.return_value = False
            with pytest.raises(HTTPException) as exc_info:
                await user_service.request_email_change(FAKE_USER_ID, "new@example.com", "wrong")
        assert exc_info.value.status_code == 401

    @pytest.mark.asyncio
    async def test_email_taken_raises_400(self, user_service, mock_auth_repo, fake_user_dict):
        mock_auth_repo.get_user_by_id.return_value = fake_user_dict
        mock_auth_repo.get_user_by_email.return_value = _make_user_obj(id="other-user-id")
        with patch("services.users.users.Security") as MockSec:
            MockSec.verify_password.return_value = True
            with pytest.raises(HTTPException) as exc_info:
                await user_service.request_email_change(FAKE_USER_ID, "taken@example.com", "Secure1!x")
        assert exc_info.value.status_code == 400
