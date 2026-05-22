"""Tests for services/emailing/otp_service.py — OTP generation, rate limiting, email sending."""

from datetime import datetime, timedelta, timezone
from unittest.mock import MagicMock, patch, AsyncMock

import pytest

from core.exceptions import TooManyCodeRequests
from services.emailing.otp_service import OtpService
from tests.conftest import FAKE_USER_ID, _make_user_obj


@pytest.fixture
def otp_service(mock_auth_repo):
    with patch("services.emailing.otp_service.EmailSender") as MockEmailSender:
        MockEmailSender.return_value = MagicMock()
        svc = OtpService(mock_auth_repo)
        svc._mock_email_sender = MockEmailSender
        yield svc


# ─── send_verification_otp ───────────────────────────────────────────

class TestSendVerificationOtp:
    @pytest.mark.asyncio
    async def test_generates_and_sends(self, otp_service, mock_auth_repo):
        with patch("services.emailing.otp_service.Security") as MockSec:
            MockSec.generate_otp_code.return_value = "654321"
            MockSec.hash_token.return_value = "hashed-code"
            await otp_service.send_verification_otp("john@example.com", FAKE_USER_ID)

        mock_auth_repo.update_user.assert_called_once()
        call_data = mock_auth_repo.update_user.call_args[0][1]
        assert call_data["verification_code_hash"] == "hashed-code"
        assert call_data["verification_attempts"] == 0
        otp_service._mock_email_sender.return_value.send_verification_email.assert_called_once()

    @pytest.mark.asyncio
    async def test_rate_limit_on_resend(self, otp_service, mock_auth_repo):
        rate_limited = _make_user_obj(
            is_verified=False,
            last_code_sent_at=datetime.now(timezone.utc) - timedelta(minutes=5),
            code_resend_count=5,
        )
        with pytest.raises(TooManyCodeRequests):
            await otp_service.send_verification_otp("john@example.com", FAKE_USER_ID, db_user=rate_limited)

    @pytest.mark.asyncio
    async def test_resets_count_after_one_hour(self, otp_service, mock_auth_repo):
        old_user = _make_user_obj(
            is_verified=False,
            last_code_sent_at=datetime.now(timezone.utc) - timedelta(hours=2),
            code_resend_count=5,
        )
        with patch("services.emailing.otp_service.Security") as MockSec:
            MockSec.generate_otp_code.return_value = "654321"
            MockSec.hash_token.return_value = "hashed-code"
            await otp_service.send_verification_otp("john@example.com", FAKE_USER_ID, db_user=old_user)

        call_data = mock_auth_repo.update_user.call_args[0][1]
        assert call_data["code_resend_count"] == 1


# ─── send_reset_otp ─────────────────────────────────────────────────

class TestSendResetOtp:
    @pytest.mark.asyncio
    async def test_generates_and_sends(self, otp_service, mock_auth_repo):
        with patch("services.emailing.otp_service.Security") as MockSec:
            MockSec.generate_otp_code.return_value = "654321"
            MockSec.hash_token.return_value = "hashed-code"
            await otp_service.send_reset_otp("john@example.com")

        mock_auth_repo.save_reset_code.assert_called_once()
        otp_service._mock_email_sender.return_value.send_reset_password_email.assert_called_once()


# ─── send_email_change_otp ───────────────────────────────────────────

class TestSendEmailChangeOtp:
    @pytest.mark.asyncio
    async def test_generates_and_sends(self, otp_service, mock_auth_repo):
        with patch("services.emailing.otp_service.Security") as MockSec:
            MockSec.generate_otp_code.return_value = "654321"
            MockSec.hash_token.return_value = "hashed-code"
            await otp_service.send_email_change_otp("new@example.com", FAKE_USER_ID)

        mock_auth_repo.update_user.assert_called_once()
        call_data = mock_auth_repo.update_user.call_args[0][1]
        assert call_data["email_change_code_hash"] == "hashed-code"
        otp_service._mock_email_sender.return_value.send_email_change_email.assert_called_once()

    @pytest.mark.asyncio
    async def test_rate_limit_on_resend(self, otp_service, mock_auth_repo):
        rate_limited = _make_user_obj(
            pending_email="new@example.com",
            last_code_sent_at=datetime.now(timezone.utc) - timedelta(minutes=5),
            code_resend_count=5,
        )
        with pytest.raises(TooManyCodeRequests):
            await otp_service.send_email_change_otp("new@example.com", FAKE_USER_ID, db_user=rate_limited)
