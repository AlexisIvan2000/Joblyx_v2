"""Tests for services/onboarding/onboarding_service.py."""

import pytest
from fastapi import HTTPException

from models.schemas import OnboardingRequest, UserSkillCreate, SkillLevel, UserLevel, Language
from services.onboarding.onboarding_service import OnboardingService
from tests.conftest import FAKE_USER_ID, FAKE_ROADMAP_ID


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
    def test_success(self, mock_career_repo):
        svc = OnboardingService(mock_career_repo)
        result = svc.complete_onboarding(FAKE_USER_ID, _make_valid_request())
        assert result["message"] == "Onboarding completed successfully"
        assert result["roadmap_id"] == FAKE_ROADMAP_ID

    def test_profile_data_correct(self, mock_career_repo):
        svc = OnboardingService(mock_career_repo)
        svc.complete_onboarding(FAKE_USER_ID, _make_valid_request())
        call_args = mock_career_repo.create_career_profile.call_args[0][0]
        assert call_args["user_id"] == FAKE_USER_ID
        assert call_args["level"] == "junior"
        assert call_args["years_experience"] == 2
        assert call_args["target_jobs"] == ["Developer"]
        assert call_args["city"] == "Montreal"
        assert call_args["province"] == "Quebec"
        assert call_args["language"] == "fr"
        assert call_args["onboarding_completed"] is True

    def test_skills_data_correct(self, mock_career_repo):
        svc = OnboardingService(mock_career_repo)
        svc.complete_onboarding(FAKE_USER_ID, _make_valid_request())
        call_args = mock_career_repo.create_user_skills.call_args[0][0]
        assert len(call_args) == 1
        assert call_args[0]["user_id"] == FAKE_USER_ID
        assert call_args[0]["skill_name"] == "Python"
        assert call_args[0]["category"] == "Programming"
        assert call_args[0]["level"] == "advanced"

    def test_roadmap_stub_processing(self, mock_career_repo):
        svc = OnboardingService(mock_career_repo)
        svc.complete_onboarding(FAKE_USER_ID, _make_valid_request())
        call_args = mock_career_repo.create_roadmap.call_args[0][0]
        assert call_args["status"] == "processing"
        assert call_args["duration_days"] == 60
        assert call_args["user_id"] == FAKE_USER_ID

    def test_already_onboarded_returns_409(self, mock_career_repo):
        mock_career_repo.get_career_profile_by_user_id.return_value = {"id": "existing"}
        svc = OnboardingService(mock_career_repo)
        with pytest.raises(HTTPException) as exc_info:
            svc.complete_onboarding(FAKE_USER_ID, _make_valid_request())
        assert exc_info.value.status_code == 409
