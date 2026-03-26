"""Tests for services/auth/linkedin.py — LinkedIn OAuth business logic."""

from unittest.mock import AsyncMock, patch

import pytest
from fastapi import HTTPException

from services.auth.linkedin import LinkedInAuth
from tests.conftest import FAKE_USER_ID, _make_user_obj


# ─── Fixtures ───────────────────────────────────────────────────────

FAKE_LINKEDIN_ID = "linkedin_abc123"
FAKE_LINKEDIN_PROFILE = {
    "sub": FAKE_LINKEDIN_ID,
    "email": "john@example.com",
    "given_name": "John",
    "family_name": "Doe",
    "picture": "https://media.licdn.com/photo.jpg",
}


@pytest.fixture
def linkedin_auth(mock_auth_repo, mock_refresh_token_repo):
    return LinkedInAuth(mock_auth_repo, mock_refresh_token_repo)


def _patch_linkedin_api(profile=None):
    """Patch les appels HTTP vers LinkedIn (exchange_code + get_profile)."""
    if profile is None:
        profile = FAKE_LINKEDIN_PROFILE

    return patch.multiple(
        "services.auth.linkedin.LinkedInAuth",
        _exchange_code=AsyncMock(return_value="fake_access_token"),
        _get_profile=AsyncMock(return_value=profile),
    )


# ─── Cas 1 : Nouveau compte ─────────────────────────────────────────

class TestLinkedInNewAccount:
    @pytest.mark.asyncio
    async def test_creates_user_when_no_account_exists(
        self, linkedin_auth, mock_auth_repo, mock_refresh_token_repo,
    ):
        mock_auth_repo.get_user_by_linkedin_id.return_value = None
        mock_auth_repo.get_user_by_email.return_value = None
        new_user = _make_user_obj(linkedin_id=FAKE_LINKEDIN_ID)
        mock_auth_repo.create_user.return_value = new_user

        with _patch_linkedin_api():
            result = await linkedin_auth.authenticate("fake_code")

        assert "access_token" in result
        assert "refresh_token" in result
        assert result["token_type"] == "bearer"

        # Vérifie que create_user a été appelé avec les bonnes données
        call_args = mock_auth_repo.create_user.call_args[0][0]
        assert call_args["email"] == "john@example.com"
        assert call_args["first_name"] == "John"
        assert call_args["last_name"] == "Doe"
        assert call_args["linkedin_id"] == FAKE_LINKEDIN_ID
        assert call_args["password_hash"] is None
        assert call_args["is_verified"] is True
        assert call_args["avatar_url"] == "https://media.licdn.com/photo.jpg"

    @pytest.mark.asyncio
    async def test_new_account_issues_refresh_token(
        self, linkedin_auth, mock_auth_repo, mock_refresh_token_repo,
    ):
        mock_auth_repo.get_user_by_linkedin_id.return_value = None
        mock_auth_repo.get_user_by_email.return_value = None
        mock_auth_repo.create_user.return_value = _make_user_obj(linkedin_id=FAKE_LINKEDIN_ID)

        with _patch_linkedin_api():
            await linkedin_auth.authenticate("fake_code")

        mock_refresh_token_repo.create.assert_called_once()


# ─── Cas 2 : Compte existant avec le même email ─────────────────────

class TestLinkedInLinkExistingAccount:
    @pytest.mark.asyncio
    async def test_links_linkedin_id_to_existing_account(
        self, linkedin_auth, mock_auth_repo,
    ):
        existing_user = _make_user_obj(linkedin_id=None)
        mock_auth_repo.get_user_by_linkedin_id.return_value = None
        mock_auth_repo.get_user_by_email.return_value = existing_user

        with _patch_linkedin_api():
            result = await linkedin_auth.authenticate("fake_code")

        assert "access_token" in result
        # Vérifie que linkedin_id a été lié
        mock_auth_repo.update_user.assert_any_call(
            FAKE_USER_ID, {"linkedin_id": FAKE_LINKEDIN_ID}
        )

    @pytest.mark.asyncio
    async def test_sets_avatar_if_user_has_none(
        self, linkedin_auth, mock_auth_repo,
    ):
        existing_user = _make_user_obj(linkedin_id=None, avatar_url=None)
        mock_auth_repo.get_user_by_linkedin_id.return_value = None
        mock_auth_repo.get_user_by_email.return_value = existing_user

        with _patch_linkedin_api():
            await linkedin_auth.authenticate("fake_code")

        # Vérifie que l'avatar a été mis à jour
        mock_auth_repo.update_user.assert_any_call(
            FAKE_USER_ID, {"avatar_url": "https://media.licdn.com/photo.jpg"}
        )

    @pytest.mark.asyncio
    async def test_keeps_existing_avatar(
        self, linkedin_auth, mock_auth_repo,
    ):
        existing_user = _make_user_obj(linkedin_id=None, avatar_url="https://existing.jpg")
        mock_auth_repo.get_user_by_linkedin_id.return_value = None
        mock_auth_repo.get_user_by_email.return_value = existing_user

        with _patch_linkedin_api():
            await linkedin_auth.authenticate("fake_code")

        # update_user appelé uniquement pour linkedin_id, pas pour avatar
        calls = [c[0] for c in mock_auth_repo.update_user.call_args_list]
        avatar_calls = [c for c in calls if "avatar_url" in c[1]]
        assert len(avatar_calls) == 0

    @pytest.mark.asyncio
    async def test_auto_verifies_unverified_account(
        self, linkedin_auth, mock_auth_repo,
    ):
        unverified_user = _make_user_obj(linkedin_id=None, is_verified=False)
        mock_auth_repo.get_user_by_linkedin_id.return_value = None
        mock_auth_repo.get_user_by_email.return_value = unverified_user

        with _patch_linkedin_api():
            await linkedin_auth.authenticate("fake_code")

        mock_auth_repo.update_verification_status.assert_called_once_with(FAKE_USER_ID)


# ─── Cas 3 : Reconnexion (compte déjà lié) ──────────────────────────

class TestLinkedInReconnect:
    @pytest.mark.asyncio
    async def test_login_by_linkedin_id(
        self, linkedin_auth, mock_auth_repo,
    ):
        linked_user = _make_user_obj(linkedin_id=FAKE_LINKEDIN_ID)
        mock_auth_repo.get_user_by_linkedin_id.return_value = linked_user

        with _patch_linkedin_api():
            result = await linkedin_auth.authenticate("fake_code")

        assert "access_token" in result
        # Ne doit PAS appeler create_user ni get_user_by_email
        mock_auth_repo.create_user.assert_not_called()
        mock_auth_repo.get_user_by_email.assert_not_called()


# ─── Cas d'erreur ────────────────────────────────────────────────────

class TestLinkedInErrors:
    @pytest.mark.asyncio
    async def test_no_email_raises_400(
        self, linkedin_auth, mock_auth_repo,
    ):
        profile_no_email = {
            "sub": FAKE_LINKEDIN_ID,
            "given_name": "John",
            "family_name": "Doe",
        }
        with _patch_linkedin_api(profile=profile_no_email):
            with pytest.raises(HTTPException) as exc_info:
                await linkedin_auth.authenticate("fake_code")
            assert exc_info.value.status_code == 400
            assert "no email" in exc_info.value.detail.lower()

    @pytest.mark.asyncio
    async def test_invalid_code_raises_401(
        self, linkedin_auth,
    ):
        with patch.object(
            LinkedInAuth, "_exchange_code",
            side_effect=HTTPException(status_code=401, detail="Failed to authenticate with LinkedIn"),
        ):
            with pytest.raises(HTTPException) as exc_info:
                await linkedin_auth.authenticate("bad_code")
            assert exc_info.value.status_code == 401


# ─── Protection login email/password pour compte LinkedIn ────────────

class TestLinkedInOnlyAccountBlocked:
    @pytest.mark.asyncio
    async def test_email_login_blocked_for_linkedin_account(
        self, auth_service, mock_auth_repo,
    ):
        """Un compte créé via LinkedIn (password_hash=None) ne peut pas se connecter par email/password."""
        linkedin_user = _make_user_obj(password_hash=None, linkedin_id=FAKE_LINKEDIN_ID)
        mock_auth_repo.get_user_by_email.return_value = linkedin_user

        from models.schemas import UserLogin
        with pytest.raises(HTTPException) as exc_info:
            await auth_service.login_user(UserLogin(email="john@example.com", password="Secure1!x"))
        assert exc_info.value.status_code == 400
        assert "linkedin" in exc_info.value.detail.lower()

    @pytest.mark.asyncio
    async def test_forgot_password_blocked_for_linkedin_account(
        self, mock_auth_repo, mock_otp_service, mock_refresh_token_repo,
    ):
        """Un compte LinkedIn-only ne peut pas demander un reset de mot de passe."""
        from services.users.users import UserService
        linkedin_user = _make_user_obj(password_hash=None, linkedin_id=FAKE_LINKEDIN_ID)
        mock_auth_repo.get_user_by_email.return_value = linkedin_user

        user_svc = UserService(mock_auth_repo, mock_otp_service, mock_refresh_token_repo)
        with pytest.raises(HTTPException) as exc_info:
            await user_svc.forgot_password("john@example.com")
        assert exc_info.value.status_code == 400
        assert "linkedin" in exc_info.value.detail.lower()
