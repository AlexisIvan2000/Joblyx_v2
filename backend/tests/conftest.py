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
os.environ.setdefault("R2_ACCESS_KEY_ID", "fake-r2-key")
os.environ.setdefault("R2_SECRET_ACCESS_KEY", "fake-r2-secret")
os.environ.setdefault("R2_ENDPOINT_URL", "https://fake.r2.cloudflarestorage.com")
os.environ.setdefault("R2_BUCKET_NAME_RESUMES", "test-cvs")
os.environ.setdefault("R2_BUCKET_NAME_IMAGES", "test-avatars")
# Désactive Sentry en test pour ne pas envoyer d'events réels
os.environ["SENTRY_DSN"] = ""

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
        "linkedin_id": None,
        "role": "user",
        "is_active": True,
        "deactivated_at": None,
        "deactivation_reason": None,
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
    repo.get_user_by_linkedin_id.return_value = None
    repo.create_user.return_value = _make_user_obj()
    repo.update_user.return_value = _make_user_obj()
    repo.update_verification_status.return_value = _make_user_obj()
    repo.save_reset_code.return_value = _make_user_obj()
    repo.update_password.return_value = _make_user_obj()
    repo.increment_verification_attempts.return_value = None
    repo.reset_verification_attempts.return_value = None
    return repo


# ─── Mock OtpService ─────────────────────────────────────────────────

@pytest.fixture
def mock_otp_service():
    svc = AsyncMock()
    svc.send_verification_otp.return_value = None
    svc.send_reset_otp.return_value = None
    svc.send_email_change_otp.return_value = None
    return svc


# ─── Mock RefreshTokenRepository ────────────────────────────────────

@pytest.fixture
def mock_refresh_token_repo():
    repo = AsyncMock()
    repo.create.return_value = MagicMock()
    repo.get_by_token_hash.return_value = None
    repo.revoke.return_value = None
    repo.revoke_all_for_user.return_value = None
    return repo


# ─── Auth service with mocked deps ───────────────────────────────────

@pytest.fixture
def auth_service(mock_auth_repo, mock_refresh_token_repo, mock_otp_service):
    from services.auth.email_password import EmailPasswordAuth
    return EmailPasswordAuth(mock_auth_repo, mock_refresh_token_repo, mock_otp_service)


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
def test_client(mock_auth_repo, mock_refresh_token_repo, mock_otp_service, fake_user_dict):
    from fastapi.testclient import TestClient
    from app import app
    from api.v1.client.dependencies import get_auth_service, get_user_service, get_current_user, get_roadmap_service, get_application_service
    from services.auth.email_password import EmailPasswordAuth
    from services.users.users import UserService

    auth_svc = EmailPasswordAuth(mock_auth_repo, mock_refresh_token_repo, mock_otp_service)
    user_svc = UserService(mock_auth_repo, mock_otp_service)

    # Mock RoadmapService pour les routes /roadmap
    roadmap_svc = AsyncMock()
    roadmap_svc._get_career = AsyncMock(return_value=MagicMock(generation_status="idle"))
    roadmap_svc.repo = AsyncMock()
    roadmap_svc.repo.get_active_roadmap = AsyncMock(return_value=None)
    roadmap_svc.repo.get_history = AsyncMock(return_value=[])
    roadmap_svc.repo.get_by_id = AsyncMock(return_value=None)
    roadmap_svc.repo.get_phase = AsyncMock(return_value=None)
    roadmap_svc.repo.create_roadmap = AsyncMock()
    roadmap_svc.repo.create_phases = AsyncMock()
    roadmap_svc.repo.archive_active = AsyncMock()
    roadmap_svc.generate = AsyncMock()
    async def _mock_generate_stream(user_id):
        yield 'event: status\ndata: {"status":"generating"}\n\n'
        yield 'event: complete\ndata: {"status":"ready"}\n\n'
    roadmap_svc.generate_stream = _mock_generate_stream
    roadmap_svc.save_career_and_skills = AsyncMock(return_value=True)
    roadmap_svc.check_regeneration_limit = AsyncMock(return_value={
        "allowed": True, "used": 0, "remaining": 5, "resets_at": "2026-04-01T00:00:00+00:00",
    })
    roadmap_svc.session = AsyncMock()

    async def override_auth_service():
        return auth_svc

    async def override_user_service():
        return user_svc

    async def override_current_user():
        return fake_user_dict

    async def override_roadmap_service():
        return roadmap_svc

    # Mock ApplicationService
    app_svc = AsyncMock()
    app_svc.create = AsyncMock()
    app_svc.get_by_id = AsyncMock()
    app_svc.get_all = AsyncMock(return_value=[])
    app_svc.update = AsyncMock()
    app_svc.delete = AsyncMock()
    app_svc.get_cv_url = AsyncMock(return_value="https://example.com/cv.pdf")

    async def override_application_service():
        return app_svc

    app.dependency_overrides[get_auth_service] = override_auth_service
    app.dependency_overrides[get_user_service] = override_user_service
    app.dependency_overrides[get_current_user] = override_current_user
    app.dependency_overrides[get_roadmap_service] = override_roadmap_service
    app.dependency_overrides[get_application_service] = override_application_service

    client = TestClient(app)
    client._mock_otp_service = mock_otp_service
    client._mock_roadmap_svc = roadmap_svc
    client._mock_app_svc = app_svc

    yield client

    app.dependency_overrides.clear()
