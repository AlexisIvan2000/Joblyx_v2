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
)


# ─── UserCreate ───────────────────────────────────────────────────────

class TestUserCreate:
    def test_valid(self):
        u = UserCreate(
            first_name="John",
            last_name="Doe",
            email="john@example.com",
            password="Secure1!x",
        )
        assert u.email == "john@example.com"

    def test_invalid_email(self):
        with pytest.raises(ValidationError):
            UserCreate(
                first_name="John",
                last_name="Doe",
                email="not-an-email",
                password="Secure1!x",
            )

    def test_password_too_short(self):
        with pytest.raises(ValidationError, match="8 characters"):
            UserCreate(
                first_name="John",
                last_name="Doe",
                email="john@example.com",
                password="Sh1!",
            )

    def test_password_no_special_char(self):
        with pytest.raises(ValidationError, match="special character"):
            UserCreate(
                first_name="John",
                last_name="Doe",
                email="john@example.com",
                password="NoSpecial123",
            )

    def test_password_exactly_8_chars_with_special(self):
        u = UserCreate(
            first_name="A",
            last_name="B",
            email="a@b.com",
            password="12345!ab",
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
