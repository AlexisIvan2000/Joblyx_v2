import pytest
from unittest.mock import patch


@pytest.fixture
def email_sender():
    with patch("services.emailing.email_sender.resend") as mock_resend:
        mock_resend.Emails.send.return_value = {"id": "fake-email-id"}
        from services.emailing.email_sender import EmailSender
        svc = EmailSender()
        yield svc, mock_resend


class TestSendVerificationEmail:
    @pytest.mark.asyncio
    async def test_sends_with_correct_params(self, email_sender):
        """Vérifie que send_verification_email envoie avec les bons paramètres."""
        svc, mock_resend = email_sender
        await svc.send_verification_email("user@example.com", "123456")

        mock_resend.Emails.send.assert_called_once()
        call_args = mock_resend.Emails.send.call_args[0][0]
        assert call_args["to"] == ["user@example.com"]
        assert "123456" in call_args["html"]
        assert call_args["subject"] == "Email verification"

    @pytest.mark.asyncio
    async def test_returns_response(self, email_sender):
        """Vérifie que send_verification_email retourne la réponse de resend."""
        svc, _ = email_sender
        result = await svc.send_verification_email("user@example.com", "999999")

        assert result == {"id": "fake-email-id"}

    @pytest.mark.asyncio
    async def test_html_contains_welcome_text(self, email_sender):
        """Vérifie que le HTML contient le texte de bienvenue."""
        svc, mock_resend = email_sender
        await svc.send_verification_email("user@example.com", "654321")

        call_args = mock_resend.Emails.send.call_args[0][0]
        assert "Welcome to Joblyx" in call_args["html"]


class TestSendResetPasswordEmail:
    @pytest.mark.asyncio
    async def test_sends_with_correct_params(self, email_sender):
        """Vérifie que send_reset_password_email envoie avec les bons paramètres."""
        svc, mock_resend = email_sender
        await svc.send_reset_password_email("user@example.com", "654321")

        mock_resend.Emails.send.assert_called_once()
        call_args = mock_resend.Emails.send.call_args[0][0]
        assert call_args["to"] == ["user@example.com"]
        assert "654321" in call_args["html"]
        assert call_args["subject"] == "Password reset"

    @pytest.mark.asyncio
    async def test_returns_response(self, email_sender):
        """Vérifie que send_reset_password_email retourne la réponse de resend."""
        svc, _ = email_sender
        result = await svc.send_reset_password_email("user@example.com", "111111")

        assert result == {"id": "fake-email-id"}

    @pytest.mark.asyncio
    async def test_html_contains_reset_text(self, email_sender):
        """Vérifie que le HTML contient le texte de réinitialisation."""
        svc, mock_resend = email_sender
        await svc.send_reset_password_email("user@example.com", "654321")

        call_args = mock_resend.Emails.send.call_args[0][0]
        assert "Password Reset Request" in call_args["html"]


class TestSendEmailChangeEmail:
    @pytest.mark.asyncio
    async def test_sends_with_correct_params(self, email_sender):
        """Vérifie que send_email_change_email envoie avec les bons paramètres."""
        svc, mock_resend = email_sender
        await svc.send_email_change_email("new@example.com", "789012")

        mock_resend.Emails.send.assert_called_once()
        call_args = mock_resend.Emails.send.call_args[0][0]
        assert call_args["to"] == ["new@example.com"]
        assert "789012" in call_args["html"]
        assert call_args["subject"] == "Email change verification"

    @pytest.mark.asyncio
    async def test_returns_response(self, email_sender):
        """Vérifie que send_email_change_email retourne la réponse de resend."""
        svc, _ = email_sender
        result = await svc.send_email_change_email("new@example.com", "222222")

        assert result == {"id": "fake-email-id"}

    @pytest.mark.asyncio
    async def test_html_contains_change_text(self, email_sender):
        """Vérifie que le HTML contient le texte de changement d'email."""
        svc, mock_resend = email_sender
        await svc.send_email_change_email("new@example.com", "789012")

        call_args = mock_resend.Emails.send.call_args[0][0]
        assert "Email Change Request" in call_args["html"]
