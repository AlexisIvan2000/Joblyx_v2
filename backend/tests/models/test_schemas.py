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
    UserSkillCreate,
    OnboardingRequest,
    OnboardingResponse,
    SkillLevel,
    UserLevel,
    Language,
)


# ─── UserCreate ───────────────────────────────────────────────────────

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

    def test_password_too_short(self):
        with pytest.raises(ValidationError, match="8 characters"):
            UserCreate(
                first_name="John",
                last_name="Doe",
                email="john@example.com",
                password="Sh1!",
                avatar_url="https://example.com/avatar.png",
            )

    def test_password_no_special_char(self):
        with pytest.raises(ValidationError, match="special character"):
            UserCreate(
                first_name="John",
                last_name="Doe",
                email="john@example.com",
                password="NoSpecial123",
                avatar_url="https://example.com/avatar.png",
            )

    def test_password_exactly_8_chars_with_special(self):
        u = UserCreate(
            first_name="A",
            last_name="B",
            email="a@b.com",
            password="12345!ab",
            avatar_url="https://example.com/avatar.png",
        )
        assert u.password == "12345!ab"


# ─── ChangePassword ──────────────────────────────────────────────────

class TestChangePassword:
    def test_valid(self):
        cp = ChangePassword(current_password="old", new_password="NewPass1!")
        assert cp.new_password == "NewPass1!"

    def test_new_password_too_short(self):
        with pytest.raises(ValidationError, match="8 characters"):
            ChangePassword(current_password="old", new_password="Sh1!")

    def test_new_password_no_special_char(self):
        with pytest.raises(ValidationError, match="special character"):
            ChangePassword(current_password="old", new_password="NoSpecial123")


# ─── UpdateProfile ───────────────────────────────────────────────────

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


# ─── ChangeEmail ─────────────────────────────────────────────────────

class TestChangeEmail:
    def test_valid(self):
        ce = ChangeEmail(new_email="new@example.com", password="pass")
        assert ce.new_email == "new@example.com"

    def test_invalid_email(self):
        with pytest.raises(ValidationError):
            ChangeEmail(new_email="bad-email", password="pass")


# ─── Other simple schemas ────────────────────────────────────────────

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


# ─── UserSkillCreate ────────────────────────────────────────────────

class TestUserSkillCreate:
    def test_valid(self):
        s = UserSkillCreate(skill_name="Python", category="Programming", level="advanced")
        assert s.skill_name == "Python"
        assert s.level == SkillLevel.advanced

    def test_empty_skill_name(self):
        with pytest.raises(ValidationError, match="skill_name must not be empty"):
            UserSkillCreate(skill_name="  ", category="Programming", level="advanced")

    def test_invalid_level(self):
        with pytest.raises(ValidationError):
            UserSkillCreate(skill_name="Python", category="Programming", level="expert")


# ─── OnboardingRequest ──────────────────────────────────────────────

def _valid_onboarding(**overrides):
    defaults = dict(
        level="junior",
        years_experience=2,
        target_jobs=["Developer"],
        city="Montreal",
        province="Quebec",
        language="fr",
        skills=[{"skill_name": "Python", "category": "Programming", "level": "advanced"}],
    )
    defaults.update(overrides)
    return OnboardingRequest(**defaults)


class TestOnboardingRequest:
    def test_valid_complete(self):
        req = _valid_onboarding()
        assert req.level == UserLevel.junior
        assert req.language == Language.fr

    def test_empty_skills(self):
        with pytest.raises(ValidationError, match="At least one skill"):
            _valid_onboarding(skills=[])

    def test_too_many_target_jobs(self):
        with pytest.raises(ValidationError, match="Maximum 3"):
            _valid_onboarding(target_jobs=["A", "B", "C", "D"])

    def test_empty_target_jobs(self):
        with pytest.raises(ValidationError, match="At least one target job"):
            _valid_onboarding(target_jobs=[])

    def test_negative_years(self):
        with pytest.raises(ValidationError, match="between 0 and 50"):
            _valid_onboarding(years_experience=-1)

    def test_invalid_level(self):
        with pytest.raises(ValidationError):
            _valid_onboarding(level="senior")

    def test_strip_target_jobs(self):
        req = _valid_onboarding(target_jobs=["  Dev  ", " PM "])
        assert req.target_jobs == ["Dev", "PM"]

    def test_whitespace_only_target_jobs_removed(self):
        with pytest.raises(ValidationError, match="At least one target job"):
            _valid_onboarding(target_jobs=["  ", ""])

    def test_years_over_50(self):
        with pytest.raises(ValidationError, match="between 0 and 50"):
            _valid_onboarding(years_experience=51)

    def test_three_target_jobs_valid(self):
        req = _valid_onboarding(target_jobs=["Dev", "PM", "QA"])
        assert len(req.target_jobs) == 3
