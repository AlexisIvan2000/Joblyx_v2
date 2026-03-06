"""Tests for services/onboarding/onboarding_service.py."""

from unittest.mock import MagicMock

import pytest
from fastapi import HTTPException

from models.schemas import OnboardingRequest, SkillItem, SkillLevel, UserLevel, Language
from services.onboarding.onboarding_service import OnboardingService
from tests.conftest import FAKE_USER_ID


def _make_request(**overrides):
    defaults = dict(
        level=UserLevel.junior,
        years_experience=2,
        target_jobs=["Developer"],
        city="Montreal",
        province="Quebec",
        language=Language.fr,
        skills=[SkillItem(skill_name="Python", category="Programming", proficiency=SkillLevel.advanced)],
    )
    defaults.update(overrides)
    return OnboardingRequest(**defaults)


# ─── complete_onboarding ────────────────────────────────────────────

class TestCompleteOnboarding:
    @pytest.mark.asyncio
    async def test_success(self, mock_onboarding_repo):
        svc = OnboardingService(mock_onboarding_repo)
        result = await svc.complete_onboarding(FAKE_USER_ID, _make_request())

        assert result["onboarding_completed"] is True
        assert result["level"] == "junior"
        assert len(result["skills"]) == 1
        mock_onboarding_repo.create_career.assert_called_once()
        mock_onboarding_repo.create_user_skills.assert_called_once()

    @pytest.mark.asyncio
    async def test_already_completed_raises_409(self, mock_onboarding_repo):
        mock_onboarding_repo.has_profile.return_value = True
        svc = OnboardingService(mock_onboarding_repo)

        with pytest.raises(HTTPException) as exc_info:
            await svc.complete_onboarding(FAKE_USER_ID, _make_request())
        assert exc_info.value.status_code == 409

    @pytest.mark.asyncio
    async def test_career_data_passed_correctly(self, mock_onboarding_repo):
        svc = OnboardingService(mock_onboarding_repo)
        req = _make_request(previous_field="Marketing")
        await svc.complete_onboarding(FAKE_USER_ID, req)

        call_args = mock_onboarding_repo.create_career.call_args
        assert call_args[0][0] == FAKE_USER_ID
        data = call_args[0][1]
        assert data["level"] == "junior"
        assert data["city"] == "Montreal"
        assert data["previous_field"] == "Marketing"

    @pytest.mark.asyncio
    async def test_skills_data_passed_correctly(self, mock_onboarding_repo):
        svc = OnboardingService(mock_onboarding_repo)
        req = _make_request(skills=[
            SkillItem(skill_name="Python", category="Programming", proficiency=SkillLevel.advanced),
            SkillItem(skill_name="SQL", category="Database", proficiency=SkillLevel.intermediate),
        ])
        await svc.complete_onboarding(FAKE_USER_ID, req)

        call_args = mock_onboarding_repo.create_user_skills.call_args
        skills = call_args[0][1]
        assert len(skills) == 2
        assert skills[0]["skill_name"] == "Python"
        assert skills[1]["proficiency"] == "intermediate"


# ─── get_profile ────────────────────────────────────────────────────

class TestGetProfile:
    @pytest.mark.asyncio
    async def test_success(self, mock_onboarding_repo):
        svc = OnboardingService(mock_onboarding_repo)
        result = await svc.get_profile(FAKE_USER_ID)

        assert result["level"] == "junior"
        assert result["onboarding_completed"] is True
        assert result["skills"][0]["skill_name"] == "Python"

    @pytest.mark.asyncio
    async def test_no_profile_raises_404(self, mock_onboarding_repo):
        mock_onboarding_repo.get_career_by_user_id.return_value = None
        svc = OnboardingService(mock_onboarding_repo)

        with pytest.raises(HTTPException) as exc_info:
            await svc.get_profile(FAKE_USER_ID)
        assert exc_info.value.status_code == 404


# ─── update_profile ─────────────────────────────────────────────────

class TestUpdateProfile:
    @pytest.mark.asyncio
    async def test_success(self, mock_onboarding_repo):
        svc = OnboardingService(mock_onboarding_repo)
        result = await svc.update_profile(FAKE_USER_ID, _make_request())

        assert result["onboarding_completed"] is True
        mock_onboarding_repo.update_career.assert_called_once()
        mock_onboarding_repo.delete_skills_by_user_id.assert_called_once_with(FAKE_USER_ID)
        mock_onboarding_repo.create_user_skills.assert_called_once()

    @pytest.mark.asyncio
    async def test_no_profile_raises_404(self, mock_onboarding_repo):
        mock_onboarding_repo.get_career_by_user_id.return_value = None
        svc = OnboardingService(mock_onboarding_repo)

        with pytest.raises(HTTPException) as exc_info:
            await svc.update_profile(FAKE_USER_ID, _make_request())
        assert exc_info.value.status_code == 404

    @pytest.mark.asyncio
    async def test_delete_then_recreate_skills(self, mock_onboarding_repo):
        svc = OnboardingService(mock_onboarding_repo)
        req = _make_request(skills=[
            SkillItem(skill_name="React", category="Frontend", proficiency=SkillLevel.beginner),
        ])
        await svc.update_profile(FAKE_USER_ID, req)

        mock_onboarding_repo.delete_skills_by_user_id.assert_called_once_with(FAKE_USER_ID)
        skills_arg = mock_onboarding_repo.create_user_skills.call_args[0][1]
        assert skills_arg[0]["skill_name"] == "React"


# ─── check_status ───────────────────────────────────────────────────

class TestCheckStatus:
    @pytest.mark.asyncio
    async def test_no_profile(self, mock_onboarding_repo):
        mock_onboarding_repo.has_profile.return_value = False
        svc = OnboardingService(mock_onboarding_repo)
        result = await svc.check_status(FAKE_USER_ID)
        assert result == {"has_profile": False}

    @pytest.mark.asyncio
    async def test_has_profile(self, mock_onboarding_repo):
        mock_onboarding_repo.has_profile.return_value = True
        svc = OnboardingService(mock_onboarding_repo)
        result = await svc.check_status(FAKE_USER_ID)
        assert result == {"has_profile": True}
