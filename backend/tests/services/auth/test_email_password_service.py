"""Tests for services/auth/email_password.py — business logic."""

from datetime import datetime, timedelta, timezone
from unittest.mock import MagicMock, patch

import pytest

from core.exceptions import (
    DomainError,
    EmailAlreadyRegistered,
    EmailNotVerified,
    InvalidCredentials,
    InvalidRefreshToken,
    InvalidVerificationCode,
    InvalidVerificationRequest,
    NoPendingEmailChange,
    TooManyCodeRequests,
    TooManyVerificationAttempts,
    VerificationCodeExpired,
)
from models.schemas import UserCreate, UserLogin
from tests.conftest import FAKE_USER_ID, FAKE_OTP_CODE, FAKE_OTP_HASH, _make_user_obj


class TestRegisterUser:
    @pytest.mark.asyncio
    async def test_success_returns_message(self, auth_service, mock_auth_repo, mock_otp_service):
        with patch("services.auth.email_password.Security") as MockSec:
            MockSec.hash_password.return_value = "hashed"

            user = UserCreate(
                first_name="John",
                last_name="Doe",
                email="john@example.com",
                password="Secure1!x",
            )
            result = await auth_service.register_user(user)

        assert "message" in result
        assert "access_token" not in result
        mock_otp_service.send_verification_otp.assert_called_once()

    @pytest.mark.asyncio
    async def test_email_already_taken_raises_400(self, auth_service, mock_auth_repo, fake_user_dict):
        mock_auth_repo.get_user_by_email.return_value = fake_user_dict
        user = UserCreate(
            first_name="John",
            last_name="Doe",
            email="john@example.com",
            password="Secure1!x",
        )
        with pytest.raises(EmailAlreadyRegistered):
            await auth_service.register_user(user)

    @pytest.mark.asyncio
    async def test_calls_hash_password(self, auth_service, mock_auth_repo):
        with patch("services.auth.email_password.Security") as MockSec:
            MockSec.hash_password.return_value = "hashed"

            user = UserCreate(
                first_name="A", last_name="B",
                email="a@b.com", password="Secure1!x",
            )
            await auth_service.register_user(user)

        MockSec.hash_password.assert_called_once_with("Secure1!x")

    @pytest.mark.asyncio
    async def test_calls_create_user(self, auth_service, mock_auth_repo):
        with patch("services.auth.email_password.Security") as MockSec:
            MockSec.hash_password.return_value = "hashed"

            user = UserCreate(
                first_name="A", last_name="B",
                email="a@b.com", password="Secure1!x",
            )
            await auth_service.register_user(user)

        mock_auth_repo.create_user.assert_called_once()
        call_data = mock_auth_repo.create_user.call_args[0][0]
        assert call_data["email"] == "a@b.com"
        assert call_data["password_hash"] == "hashed"

    @pytest.mark.asyncio
    async def test_sends_verification_otp(self, auth_service, mock_auth_repo, mock_otp_service):
        with patch("services.auth.email_password.Security") as MockSec:
            MockSec.hash_password.return_value = "hashed"

            user = UserCreate(
                first_name="A", last_name="B",
                email="a@b.com", password="Secure1!x",
            )
            await auth_service.register_user(user)

        mock_otp_service.send_verification_otp.assert_called_once_with("a@b.com", FAKE_USER_ID)


class TestLoginUser:
    @pytest.mark.asyncio
    async def test_success_returns_tokens(self, auth_service, mock_auth_repo, fake_user_dict):
        mock_auth_repo.get_user_by_email.return_value = fake_user_dict
        with patch("services.auth.email_password.Security") as MockSec:
            MockSec.verify_password.return_value = True
            MockSec.create_access_token.return_value = "access-tok"
            MockSec.create_refresh_token.return_value = "refresh-tok"
            MockSec.hash_token.return_value = "hashed-rt"

            user = UserLogin(email="john@example.com", password="Secure1!x")
            result = await auth_service.login_user(user)

        assert result["access_token"] == "access-tok"
        assert result["refresh_token"] == "refresh-tok"

    @pytest.mark.asyncio
    async def test_unknown_email_raises_401(self, auth_service, mock_auth_repo):
        mock_auth_repo.get_user_by_email.return_value = None
        user = UserLogin(email="unknown@example.com", password="pass")
        with pytest.raises(InvalidCredentials):
            await auth_service.login_user(user)

    @pytest.mark.asyncio
    async def test_wrong_password_raises_401(self, auth_service, mock_auth_repo, fake_user_dict):
        mock_auth_repo.get_user_by_email.return_value = fake_user_dict
        with patch("services.auth.email_password.Security") as MockSec:
            MockSec.verify_password.return_value = False
            user = UserLogin(email="john@example.com", password="wrong")
            with pytest.raises(InvalidCredentials):
                await auth_service.login_user(user)

    @pytest.mark.asyncio
    async def test_unverified_user_raises_403(self, auth_service, mock_auth_repo, fake_unverified_user_dict):
        mock_auth_repo.get_user_by_email.return_value = fake_unverified_user_dict
        with patch("services.auth.email_password.Security") as MockSec:
            MockSec.verify_password.return_value = True
            user = UserLogin(email="john@example.com", password="Secure1!x")
            with pytest.raises(EmailNotVerified):
                await auth_service.login_user(user)


class TestVerifyEmail:
    @pytest.mark.asyncio
    async def test_success_returns_tokens(self, auth_service, mock_auth_repo, fake_unverified_user_dict):
        mock_auth_repo.get_user_by_email.return_value = fake_unverified_user_dict
        with patch("services.auth.email_password.Security") as MockSec:
            MockSec.hash_token.return_value = FAKE_OTP_HASH
            MockSec.create_access_token.return_value = "access-tok"
            MockSec.create_refresh_token.return_value = "refresh-tok"

            result = await auth_service.verify_email("john@example.com", FAKE_OTP_CODE)

        assert result["access_token"] == "access-tok"
        assert result["refresh_token"] == "refresh-tok"
        mock_auth_repo.update_verification_status.assert_called_once()

    @pytest.mark.asyncio
    async def test_invalid_code_raises_400(self, auth_service, mock_auth_repo, fake_unverified_user_dict):
        mock_auth_repo.get_user_by_email.return_value = fake_unverified_user_dict
        with patch("services.auth.email_password.Security") as MockSec:
            MockSec.hash_token.return_value = "wrong-hash"
            with pytest.raises(InvalidVerificationCode):
                await auth_service.verify_email("john@example.com", "000000")

    @pytest.mark.asyncio
    async def test_expired_code_raises_400(self, auth_service, mock_auth_repo):
        expired = _make_user_obj(
            is_verified=False,
            verification_code_hash=FAKE_OTP_HASH,
            verification_code_expires_at=datetime.now(timezone.utc) - timedelta(hours=1),
            verification_attempts=0,
        )
        mock_auth_repo.get_user_by_email.return_value = expired
        with patch("services.auth.email_password.Security") as MockSec:
            MockSec.hash_token.return_value = FAKE_OTP_HASH
            with pytest.raises(VerificationCodeExpired):
                await auth_service.verify_email("john@example.com", FAKE_OTP_CODE)

    @pytest.mark.asyncio
    async def test_already_verified_raises_400(self, auth_service, mock_auth_repo, fake_user_dict):
        mock_auth_repo.get_user_by_email.return_value = fake_user_dict  # is_verified=True
        with pytest.raises(InvalidVerificationRequest):
            await auth_service.verify_email("john@example.com", FAKE_OTP_CODE)

    @pytest.mark.asyncio
    async def test_brute_force_5_attempts_raises_429(self, auth_service, mock_auth_repo):
        maxed_out = _make_user_obj(
            is_verified=False,
            verification_code_hash=FAKE_OTP_HASH,
            verification_code_expires_at=datetime.now(timezone.utc) + timedelta(minutes=15),
            verification_attempts=5,
        )
        mock_auth_repo.get_user_by_email.return_value = maxed_out
        with pytest.raises(TooManyVerificationAttempts):
            await auth_service.verify_email("john@example.com", FAKE_OTP_CODE)

    @pytest.mark.asyncio
    async def test_increments_attempts_on_wrong_code(self, auth_service, mock_auth_repo, fake_unverified_user_dict):
        mock_auth_repo.get_user_by_email.return_value = fake_unverified_user_dict
        with patch("services.auth.email_password.Security") as MockSec:
            MockSec.hash_token.return_value = "wrong-hash"
            with pytest.raises(DomainError):
                await auth_service.verify_email("john@example.com", "000000")
        mock_auth_repo.increment_verification_attempts.assert_called_once()


class TestResendVerificationEmail:
    @pytest.mark.asyncio
    async def test_sends_if_unverified(self, auth_service, mock_auth_repo, mock_otp_service, fake_unverified_user_dict):
        mock_auth_repo.get_user_by_email.return_value = fake_unverified_user_dict
        result = await auth_service.resend_verification_email("john@example.com")
        assert "message" in result
        mock_otp_service.send_verification_otp.assert_called_once()

    @pytest.mark.asyncio
    async def test_no_send_if_verified(self, auth_service, mock_auth_repo, mock_otp_service, fake_user_dict):
        mock_auth_repo.get_user_by_email.return_value = fake_user_dict
        result = await auth_service.resend_verification_email("john@example.com")
        assert "message" in result
        mock_otp_service.send_verification_otp.assert_not_called()

    @pytest.mark.asyncio
    async def test_generic_message_if_not_found(self, auth_service, mock_auth_repo, mock_otp_service):
        mock_auth_repo.get_user_by_email.return_value = None
        result = await auth_service.resend_verification_email("nope@example.com")
        assert "message" in result

    @pytest.mark.asyncio
    async def test_rate_limit_raises_429(self, auth_service, mock_auth_repo, mock_otp_service):
        rate_limited = _make_user_obj(
            is_verified=False,
            verification_code_hash=FAKE_OTP_HASH,
            verification_code_expires_at=datetime.now(timezone.utc) + timedelta(minutes=15),
            last_code_sent_at=datetime.now(timezone.utc) - timedelta(minutes=5),
            code_resend_count=5,
        )
        mock_auth_repo.get_user_by_email.return_value = rate_limited
        mock_otp_service.send_verification_otp.side_effect = TooManyCodeRequests()
        with pytest.raises(TooManyCodeRequests):
            await auth_service.resend_verification_email("john@example.com")


class TestResendEmailChangeVerification:
    @pytest.mark.asyncio
    async def test_success_if_pending_email(self, auth_service, mock_auth_repo, mock_otp_service, fake_user_with_pending_email):
        mock_auth_repo.get_user_by_id.return_value = fake_user_with_pending_email
        result = await auth_service.resend_email_change_verification(FAKE_USER_ID)
        assert "resent" in result["message"].lower()
        mock_otp_service.send_email_change_otp.assert_called_once()

    @pytest.mark.asyncio
    async def test_raises_400_if_no_pending(self, auth_service, mock_auth_repo, fake_user_dict):
        mock_auth_repo.get_user_by_id.return_value = fake_user_dict
        with pytest.raises(NoPendingEmailChange):
            await auth_service.resend_email_change_verification(FAKE_USER_ID)


class TestRefreshAccessToken:
    @pytest.mark.asyncio
    async def test_success(self, auth_service, mock_refresh_token_repo):
        mock_refresh_token_repo.get_by_token_hash.return_value = MagicMock()
        with patch("services.auth.email_password.Security") as MockSec:
            MockSec.decode_token.return_value = {"sub": FAKE_USER_ID, "type": "refresh"}
            MockSec.hash_token.return_value = "hashed-rt"
            MockSec.create_access_token.return_value = "new-access-tok"
            MockSec.create_refresh_token.return_value = "new-refresh-tok"
            result = await auth_service.refresh_access_token("valid-refresh")
        assert result["access_token"] == "new-access-tok"

    @pytest.mark.asyncio
    async def test_invalid_token_raises_401(self, auth_service):
        with patch("services.auth.email_password.Security") as MockSec:
            MockSec.decode_token.return_value = None
            with pytest.raises(InvalidRefreshToken):
                await auth_service.refresh_access_token("garbage")

    @pytest.mark.asyncio
    async def test_access_type_raises_401(self, auth_service):
        with patch("services.auth.email_password.Security") as MockSec:
            MockSec.decode_token.return_value = {"sub": FAKE_USER_ID, "type": "access"}
            with pytest.raises(InvalidRefreshToken):
                await auth_service.refresh_access_token("access-token-instead")
