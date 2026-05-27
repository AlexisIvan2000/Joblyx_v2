"""Tests for models/schemas.py — Pydantic validation."""

import pytest
from pydantic import ValidationError

from models.schemas import (
    ChangeEmail,
    ChangePassword,
    UpdateProfile,
    UserCreate,
    UserLogin,
    RefreshToken,
    ForgotPassword,
    ResetPassword,
    VerifyEmail,
    ResendVerification,
    SkillItem,
    RoadmapGenerateRequest,
    SkillLevel,
    UserLevel,
    Language,
)


#  UserCreate 

class TestUserCreate:
    def test_valid(self):
        u = UserCreate(
            first_name="John",
            last_name="Doe",
            email="john@example.com",
            password="Secure1!x",
            avatar_url="https://example.com/avatar.png",
        )
        assert u.email == "john@example.com"

    def test_invalid_email(self):
        with pytest.raises(ValidationError):
            UserCreate(
                first_name="John",
                last_name="Doe",
                email="not-an-email",
                password="Secure1!x",
                avatar_url="https://example.com/avatar.png",
            )




# ChangePassword 

class TestChangePassword:
    def test_valid(self):
        cp = ChangePassword(current_password="old", new_password="NewPass1!")
        assert cp.new_password == "NewPass1!"


#  UpdateProfile

class TestUpdateProfile:
    def test_all_none_valid(self):
        up = UpdateProfile()
        assert up.first_name is None
        assert up.last_name is None

    def test_partial_update(self):
        up = UpdateProfile(first_name="Jane")
        assert up.first_name == "Jane"
        assert up.last_name is None

    def test_full_update(self):
        up = UpdateProfile(first_name="Jane", last_name="Smith")
        assert up.first_name == "Jane"
        assert up.last_name == "Smith"


# ChangeEmail

class TestChangeEmail:
    def test_valid(self):
        ce = ChangeEmail(new_email="new@example.com", password="pass")
        assert ce.new_email == "new@example.com"

    def test_invalid_email(self):
        with pytest.raises(ValidationError):
            ChangeEmail(new_email="bad-email", password="pass")


#  Other simple schemas 

class TestSimpleSchemas:
    def test_user_login(self):
        ul = UserLogin(email="a@b.com", password="test")
        assert ul.email == "a@b.com"

    def test_refresh_token(self):
        rt = RefreshToken(refresh_token="tok")
        assert rt.refresh_token == "tok"

    def test_forgot_password_invalid_email(self):
        with pytest.raises(ValidationError):
            ForgotPassword(email="not-email")


# SkillItem

class TestSkillItem:
    def test_valid(self):
        s = SkillItem(skill_name="Python", category="Programming", proficiency="advanced")
        assert s.skill_name == "Python"
        assert s.proficiency == SkillLevel.advanced

    def test_empty_skill_name(self):
        with pytest.raises(ValidationError, match="skill_name must not be empty"):
            SkillItem(skill_name="  ", category="Programming", proficiency="advanced")

    def test_invalid_proficiency(self):
        with pytest.raises(ValidationError):
            SkillItem(skill_name="Python", category="Programming", proficiency="expert")


#  RoadmapGenerateRequest

def _valid_generate_request(**overrides):
    defaults = dict(
        level="junior",
        years_experience=2,
        target_jobs=["Developer"],
        city="Montreal",
        province="Quebec",
        language="fr",
        skills=[{"skill_name": "Python", "category": "Programming", "proficiency": "advanced"}],
    )
    defaults.update(overrides)
    return RoadmapGenerateRequest(**defaults)


class TestRoadmapGenerateRequest:
    def test_valid_complete(self):
        req = _valid_generate_request()
        assert req.level == UserLevel.junior
        assert req.language == Language.fr

    def test_empty_skills(self):
        with pytest.raises(ValidationError, match="At least one skill"):
            _valid_generate_request(skills=[])

    def test_too_many_target_jobs(self):
        with pytest.raises(ValidationError, match="Maximum 3"):
            _valid_generate_request(target_jobs=["A", "B", "C", "D"])

    def test_empty_target_jobs(self):
        with pytest.raises(ValidationError, match="At least one target job"):
            _valid_generate_request(target_jobs=[])

    def test_negative_years(self):
        with pytest.raises(ValidationError, match="between 0 and 50"):
            _valid_generate_request(years_experience=-1)

    def test_invalid_level(self):
        with pytest.raises(ValidationError):
            _valid_generate_request(level="expert")

    def test_strip_target_jobs(self):
        req = _valid_generate_request(target_jobs=["  Developer  ", " DevOps "])
        assert req.target_jobs == ["Developer", "DevOps"]

    def test_whitespace_only_target_jobs_removed(self):
        with pytest.raises(ValidationError, match="At least one target job"):
            _valid_generate_request(target_jobs=["  ", ""])

    def test_years_over_50(self):
        with pytest.raises(ValidationError, match="between 0 and 50"):
            _valid_generate_request(years_experience=51)

    def test_three_target_jobs_valid(self):
        req = _valid_generate_request(target_jobs=["Developer", "Data Engineer", "QA Engineer"])
        assert len(req.target_jobs) == 3

    def test_non_it_job_rejected(self):
        with pytest.raises(ValidationError, match="must be related to IT"):
            _valid_generate_request(target_jobs=["Boulanger"])

    def test_special_chars_rejected(self):
        with pytest.raises(ValidationError, match="invalid characters"):
            _valid_generate_request(target_jobs=["Developer; DROP TABLE"])
