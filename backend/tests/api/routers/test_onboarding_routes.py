"""Tests for api/routers/onboarding.py — onboarding route HTTP layer.

OnboardingService is now a stub that raises NotImplementedError,
so route calls return 500.
"""

import pytest

from tests.conftest import FAKE_USER_ID


VALID_BODY = {
    "level": "junior",
    "years_experience": 2,
    "target_jobs": ["Developer"],
    "city": "Montreal",
    "province": "Quebec",
    "language": "fr",
    "skills": [{"skill_name": "Python", "category": "Programming", "level": "advanced"}],
}


class TestOnboardingRoute:
    def test_raises_not_implemented(self, test_client):
        with pytest.raises(NotImplementedError):
            test_client.post("/onboarding", json=VALID_BODY)

    def test_invalid_body_returns_422(self, test_client):
        resp = test_client.post("/onboarding", json={})
        assert resp.status_code == 422
