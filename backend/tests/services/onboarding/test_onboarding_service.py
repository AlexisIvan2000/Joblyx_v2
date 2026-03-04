"""Tests for services/onboarding/onboarding_service.py — now a stub."""

import pytest

from models.schemas import OnboardingRequest, UserSkillCreate, SkillLevel, UserLevel, Language
from services.onboarding.onboarding_service import OnboardingService
from tests.conftest import FAKE_USER_ID


def _make_valid_request(**overrides):
    defaults = dict(
        level=UserLevel.junior,
        years_experience=2,
        target_jobs=["Developer"],
        city="Montreal",
        province="Quebec",
        language=Language.fr,
        skills=[UserSkillCreate(skill_name="Python", category="Programming", level=SkillLevel.advanced)],
    )
    defaults.update(overrides)
    return OnboardingRequest(**defaults)


class TestCompleteOnboarding:
    @pytest.mark.asyncio
    async def test_raises_not_implemented(self, mock_career_repo):
        svc = OnboardingService(mock_career_repo)
        with pytest.raises(NotImplementedError):
            await svc.complete_onboarding(FAKE_USER_ID, _make_valid_request())
