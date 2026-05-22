import logging
from typing import Any

import httpx

from core.config import (
    SENTRY_API_TOKEN,
    SENTRY_API_URL,
    SENTRY_ORG_SLUG,
    SENTRY_PROJECT_SLUG,
)
from core.exceptions import DomainError, ExternalServiceError

logger = logging.getLogger(__name__)


class SentryNotConfigured(DomainError):
    status_code = 503
    error_code = "sentry_not_configured"
    default_message = "Sentry API is not configured on this backend"


class SentryService:
    def __init__(self):
        self.base_url = SENTRY_API_URL
        self.token = SENTRY_API_TOKEN
        self.org = SENTRY_ORG_SLUG
        self.project = SENTRY_PROJECT_SLUG

    def _ensure_configured(self) -> None:
        if not (self.token and self.org and self.project):
            raise SentryNotConfigured()

    def _headers(self) -> dict:
        return {"Authorization": f"Bearer {self.token}"}

    async def _get(self, path: str, params: dict | None = None) -> Any:
        async with httpx.AsyncClient(timeout=15.0) as client:
            response = await client.get(
                f"{self.base_url}{path}",
                headers=self._headers(),
                params=params or {},
            )
        if response.status_code >= 400:
            logger.warning(
                "Sentry API error: status=%d path=%s body=%s",
                response.status_code, path, response.text[:300],
            )
            raise ExternalServiceError(
                f"Sentry API returned {response.status_code}",
                details={"status": response.status_code},
            )
        return response.json()

    # Liste paginée des issues du projet
    async def list_issues(
        self,
        *,
        query: str = "is:unresolved",
        cursor: str | None = None,
        limit: int = 25,
        environment: str | None = None,
    ) -> dict:
        self._ensure_configured()
        # /projects/.../issues/ n'accepte que '', '24h' ou '14d' pour statsPeriod
        params = {
            "query": query,
            "limit": str(limit),
            "statsPeriod": "14d",
        }
        if cursor:
            params["cursor"] = cursor
        if environment:
            params["environment"] = environment

        async with httpx.AsyncClient(timeout=15.0) as client:
            response = await client.get(
                f"{self.base_url}/projects/{self.org}/{self.project}/issues/",
                headers=self._headers(),
                params=params,
            )

        if response.status_code >= 400:
            logger.warning(
                "Sentry list_issues failed: status=%d body=%s",
                response.status_code, response.text[:300],
            )
            raise ExternalServiceError(
                f"Sentry API returned {response.status_code}",
                details={"status": response.status_code},
            )

        # Extrait le cursor de pagination depuis le header Link
        next_cursor = self._extract_next_cursor(response.headers.get("link", ""))

        return {
            "issues": response.json(),
            "next_cursor": next_cursor,
        }

    async def get_issue(self, issue_id: str) -> dict:
        self._ensure_configured()
        return await self._get(f"/organizations/{self.org}/issues/{issue_id}/")

    async def get_issue_events(self, issue_id: str, limit: int = 10) -> list:
        # Derniers events d'une issue (chacun avec le contexte user, request, tags)
        self._ensure_configured()
        return await self._get(
            f"/organizations/{self.org}/issues/{issue_id}/events/",
            params={"limit": str(limit), "full": "true"},
        )

    @staticmethod
    def _extract_next_cursor(link_header: str) -> str | None:
      
        if not link_header:
            return None
        for entry in link_header.split(","):
            if 'rel="next"' in entry and 'results="true"' in entry:
                for part in entry.split(";"):
                    part = part.strip()
                    if part.startswith('cursor="'):
                        return part[len('cursor="'):-1]
        return None
