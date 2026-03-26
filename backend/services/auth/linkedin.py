"""Service d'authentification via LinkedIn OAuth 2.0."""

import logging
import httpx

logger = logging.getLogger(__name__)
from datetime import datetime, timedelta, timezone

from fastapi import HTTPException, status

from core.config import LINKEDIN_CLIENT_ID, LINKEDIN_CLIENT_SECRET, LINKEDIN_REDIRECT_URI
from core.security import Security
from repositories.auth_repository import AuthRepository
from repositories.refresh_token_repository import RefreshTokenRepository


# URLs LinkedIn OAuth 2.0
_TOKEN_URL = "https://www.linkedin.com/oauth/v2/accessToken"
_USERINFO_URL = "https://api.linkedin.com/v2/userinfo"


class LinkedInAuth:
    def __init__(self, auth_repo: AuthRepository, refresh_token_repo: RefreshTokenRepository):
        self.repo = auth_repo
        self.rt_repo = refresh_token_repo

    async def authenticate(self, code: str) -> dict:
        """Échange le code OAuth contre un token LinkedIn, récupère le profil,
        puis gère les 3 cas (nouveau compte, liaison, reconnexion)."""

        # Échanger le code contre un access token LinkedIn
        linkedin_token = await self._exchange_code(code)

        # Récupérer le profil LinkedIn
        profile = await self._get_profile(linkedin_token)
        linkedin_id = profile["sub"]
        email = profile.get("email")
        first_name = profile.get("given_name", "")
        last_name = profile.get("family_name", "")
        avatar_url = profile.get("picture")

        if not email:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="LinkedIn account has no email address",
            )

        # Cas 3 — Compte déjà lié par linkedin_id
        db_user = await self.repo.get_user_by_linkedin_id(linkedin_id)
        if db_user:
            logger.info("LinkedIn login (reconnect): user_id=%s email=%s", db_user.id, email)
            return await self._issue_tokens(str(db_user.id))

        # Cas 2 — Compte existant avec le même email
        db_user = await self.repo.get_user_by_email(email)
        if db_user:
            logger.info("LinkedIn login (link existing): user_id=%s email=%s", db_user.id, email)
            # Lier le linkedin_id au compte existant
            await self.repo.update_user(str(db_user.id), {
                "linkedin_id": linkedin_id,
            })
            # Mettre à jour l'avatar si l'utilisateur n'en a pas
            if not db_user.avatar_url and avatar_url:
                await self.repo.update_user(str(db_user.id), {
                    "avatar_url": avatar_url,
                })
            # Vérifier l'email si pas encore fait (LinkedIn l'a déjà vérifié)
            if not db_user.is_verified:
                await self.repo.update_verification_status(str(db_user.id))
            return await self._issue_tokens(str(db_user.id))

        # Cas 1 — Nouveau compte
        logger.info("LinkedIn login (new account): email=%s linkedin_id=%s", email, linkedin_id)
        new_user = await self.repo.create_user({
            "first_name": first_name,
            "last_name": last_name,
            "email": email,
            "password_hash": None,
            "linkedin_id": linkedin_id,
            "is_verified": True,
            "avatar_url": avatar_url,
        })
        return await self._issue_tokens(str(new_user.id))

    async def _exchange_code(self, code: str) -> str:
        """Échange le code d'autorisation contre un access token LinkedIn."""
        async with httpx.AsyncClient() as client:
            response = await client.post(_TOKEN_URL, data={
                "grant_type": "authorization_code",
                "code": code,
                "redirect_uri": LINKEDIN_REDIRECT_URI,
                "client_id": LINKEDIN_CLIENT_ID,
                "client_secret": LINKEDIN_CLIENT_SECRET,
            })

        if response.status_code != 200:
            logger.warning("LinkedIn token exchange failed: status=%s body=%s", response.status_code, response.text[:200])
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Failed to authenticate with LinkedIn",
            )

        data = response.json()
        return data["access_token"]

    async def _get_profile(self, access_token: str) -> dict:
        """Récupère le profil utilisateur via l'API LinkedIn userinfo."""
        async with httpx.AsyncClient() as client:
            response = await client.get(
                _USERINFO_URL,
                headers={"Authorization": f"Bearer {access_token}"},
            )

        if response.status_code != 200:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Failed to fetch LinkedIn profile",
            )

        return response.json()

    async def _issue_tokens(self, user_id: str) -> dict:
        """Génère les tokens JWT (access + refresh)."""
        access_token = Security.create_access_token(user_id)
        refresh_token = Security.create_refresh_token(user_id)

        token_hash = Security.hash_token(refresh_token)
        refresh_expires = datetime.now(timezone.utc) + timedelta(days=30)
        await self.rt_repo.create(user_id, token_hash, refresh_expires)

        return {
            "access_token": access_token,
            "refresh_token": refresh_token,
            "token_type": "bearer",
        }
