import os
import uuid
import hashlib

# Set env vars BEFORE any app import (core/config.py reads them at import time)
os.environ.setdefault("DB_URL", "postgresql+asyncpg://test:test@localhost:5432/test")
os.environ.setdefault("JWT_SECRET_KEY", "test-secret-key")
os.environ.setdefault("JWT_ALGORITHM", "HS256")
os.environ.setdefault("ACCESS_TOKEN_EXPIRE_MINUTES", "60")
os.environ.setdefault("REFRESH_TOKEN_EXPIRE_DAYS", "30")
os.environ.setdefault("OPENAI_API_KEY", "fake")
os.environ.setdefault("RESEND_API_KEY", "fake")
os.environ.setdefault("RESEND_FROM_EMAIL", "test@joblyx.com")
os.environ.setdefault("RESEND_FROM_NAME", "Joblyx")
os.environ.setdefault("FRONTEND_URL", "http://localhost:3000")

import pytest
from datetime import datetime, timedelta, timezone
from unittest.mock import AsyncMock, MagicMock, patch

from models.db_models import User


# ─── User fixture data ───────────────────────────────────────────────

FAKE_USER_ID = "11111111-1111-1111-1111-111111111111"
FAKE_PASSWORD_HASH = "$argon2id$v=19$m=65536,t=3,p=4$fakesalt$fakehash"
FAKE_OTP_CODE = "123456"
FAKE_OTP_HASH = hashlib.sha256(FAKE_OTP_CODE.encode()).hexdigest()


def _make_user_obj(**overrides) -> User:
    """Build a User ORM object (detached, no DB session needed)."""
    defaults = {
        "id": uuid.UUID(FAKE_USER_ID),
        "first_name": "John",
        "last_name": "Doe",
        "email": "john@example.com",
        "password_hash": FAKE_PASSWORD_HASH,
        "is_verified": True,
        "verification_code_hash": None,
        "verification_code_expires_at": None,
        "pending_email": None,
        "reset_code_hash": None,
        "reset_code_expires_at": None,
        "email_change_code_hash": None,
        "email_change_code_expires_at": None,
        "verification_attempts": 0,
        "last_code_sent_at": None,
        "code_resend_count": 0,
        "avatar_url": None,
        "created_at": datetime.now(timezone.utc),
        "updated_at": datetime.now(timezone.utc),
    }
    defaults.update(overrides)
    return User(**defaults)


@pytest.fixture
def fake_user_dict():
    return _make_user_obj()


@pytest.fixture
def fake_unverified_user_dict():
    return _make_user_obj(
        is_verified=False,
        verification_code_hash=FAKE_OTP_HASH,
        verification_code_expires_at=datetime.now(timezone.utc) + timedelta(minutes=15),
        verification_attempts=0,
    )


@pytest.fixture
def fake_user_with_pending_email():
    return _make_user_obj(
        pending_email="newemail@example.com",
        email_change_code_hash=FAKE_OTP_HASH,
        email_change_code_expires_at=datetime.now(timezone.utc) + timedelta(minutes=15),
        verification_attempts=0,
    )


@pytest.fixture
def fake_user_with_reset_code():
    return _make_user_obj(
        reset_code_hash=FAKE_OTP_HASH,
        reset_code_expires_at=datetime.now(timezone.utc) + timedelta(minutes=15),
        verification_attempts=0,
    )


@pytest.fixture
def fake_user_with_expired_reset_code():
    return _make_user_obj(
        reset_code_hash=FAKE_OTP_HASH,
        reset_code_expires_at=datetime.now(timezone.utc) - timedelta(hours=1),
        verification_attempts=0,
    )


# ─── Mock AuthRepository ─────────────────────────────────────────────

@pytest.fixture
def mock_auth_repo():
    repo = AsyncMock()
    repo.get_user_by_email.return_value = None
    repo.get_user_by_id.return_value = None
    repo.create_user.return_value = _make_user_obj()
    repo.update_user.return_value = _make_user_obj()
    repo.update_verification_status.return_value = _make_user_obj()
    repo.save_reset_code.return_value = _make_user_obj()
    repo.update_password.return_value = _make_user_obj()
    repo.increment_verification_attempts.return_value = None
    repo.reset_verification_attempts.return_value = None
    return repo


# ─── Mock RefreshTokenRepository ────────────────────────────────────

@pytest.fixture
def mock_refresh_token_repo():
    repo = AsyncMock()
    repo.create.return_value = MagicMock()
    repo.get_by_token_hash.return_value = None
    repo.revoke.return_value = None
    repo.revoke_all_for_user.return_value = None
    return repo


# ─── Mock CareerRepository ───────────────────────────────────────────

FAKE_ROADMAP_ID = "22222222-2222-2222-2222-222222222222"

@pytest.fixture
def mock_career_repo():
    repo = AsyncMock()
    repo.get_career_profile_by_user_id.return_value = None
    repo.create_career_profile.return_value = {"id": "profile-1", "user_id": FAKE_USER_ID}
    repo.create_user_skills.return_value = []
    repo.create_roadmap.return_value = {"id": FAKE_ROADMAP_ID, "user_id": FAKE_USER_ID, "status": "processing"}
    repo.get_roadmap_by_user_id.return_value = None
    repo.get_user_skills_by_user_id.return_value = []
    return repo


# ─── Auth service with mocked repo + email ───────────────────────────

@pytest.fixture
def auth_service(mock_auth_repo, mock_refresh_token_repo):
    with patch("services.auth.email_password.EmailSender") as MockEmailSender:
        MockEmailSender.return_value = MagicMock()
        from services.auth.email_password import EmailPasswordAuth

        service = EmailPasswordAuth(mock_auth_repo, mock_refresh_token_repo)
        service._mock_email_sender = MockEmailSender
        yield service


# ─── Patch config for security module ─────────────────────────────────

@pytest.fixture(autouse=True)
def _patch_config(monkeypatch):
    monkeypatch.setattr("core.config.JWT_SECRET_KEY", "test-secret-key")
    monkeypatch.setattr("core.config.JWT_ALGORITHM", "HS256")
    monkeypatch.setattr("core.config.ACCESS_TOKEN_EXPIRE_MINUTES", 60)
    monkeypatch.setattr("core.config.REFRESH_TOKEN_EXPIRE_DAYS", 30)
    # Also patch the copies imported into core.security at module level
    monkeypatch.setattr("core.security.JWT_SECRET_KEY", "test-secret-key")
    monkeypatch.setattr("core.security.JWT_ALGORITHM", "HS256")
    monkeypatch.setattr("core.security.ACCESS_TOKEN_EXPIRE_MINUTES", 60)
    monkeypatch.setattr("core.security.REFRESH_TOKEN_EXPIRE_DAYS", 30)


# ─── FastAPI TestClient ──────────────────────────────────────────────

@pytest.fixture
def test_client(mock_auth_repo, mock_refresh_token_repo, fake_user_dict):
    from fastapi.testclient import TestClient
    from app import app
    from api.dependencies import get_auth_service, get_user_service, get_current_user, get_onboarding_service
    from services.auth.email_password import EmailPasswordAuth
    from services.users.users import UserService

    with patch("services.auth.email_password.EmailSender") as MockEmailSender, \
         patch("services.users.users.EmailSender") as MockUserEmailSender:
        MockEmailSender.return_value = MagicMock()
        MockUserEmailSender.return_value = MagicMock()
        auth_svc = EmailPasswordAuth(mock_auth_repo, mock_refresh_token_repo)
        user_svc = UserService(mock_auth_repo)

        from services.onboarding.onboarding_service import OnboardingService

        onboarding_mock_career_repo = AsyncMock()
        onboarding_mock_career_repo.get_career_profile_by_user_id.return_value = None
        onboarding_mock_career_repo.create_career_profile.return_value = {"id": "profile-1", "user_id": FAKE_USER_ID}
        onboarding_mock_career_repo.create_user_skills.return_value = []
        onboarding_mock_career_repo.create_roadmap.return_value = {"id": "roadmap-1", "user_id": FAKE_USER_ID, "status": "processing"}

        onboarding_svc = OnboardingService(onboarding_mock_career_repo)

        async def override_auth_service():
            return auth_svc

        async def override_user_service():
            return user_svc

        async def override_current_user():
            return fake_user_dict

        async def override_onboarding_service():
            return onboarding_svc

        app.dependency_overrides[get_auth_service] = override_auth_service
        app.dependency_overrides[get_user_service] = override_user_service
        app.dependency_overrides[get_current_user] = override_current_user
        app.dependency_overrides[get_onboarding_service] = override_onboarding_service

        client = TestClient(app)
        client._mock_career_repo = onboarding_mock_career_repo

        yield client

        app.dependency_overrides.clear()
