import os

# Set env vars BEFORE any app import (core/config.py reads them at import time)
os.environ.setdefault("SUPABASE_URL", "https://fake.supabase.co")
os.environ.setdefault("SUPABASE_SERVICE_ROLE_KEY", "fake-service-key")
os.environ.setdefault("SUPABASE_ANON_KEY", "fake-anon-key")
os.environ.setdefault("JWT_SECRET_KEY", "test-secret-key")
os.environ.setdefault("JWT_ALGORITHM", "HS256")
os.environ.setdefault("ACCESS_TOKEN_EXPIRE_MINUTES", "60")
os.environ.setdefault("REFRESH_TOKEN_EXPIRE_DAYS", "30")
os.environ.setdefault("OPENAI_API_KEY", "fake")
os.environ.setdefault("RESEND_API_KEY", "fake")
os.environ.setdefault("RESEND_FROM_EMAIL", "test@joblyx.com")
os.environ.setdefault("RESEND_FROM_NAME", "Joblyx")
os.environ.setdefault("FRONTEND_URL", "http://localhost:3000")

# Patch supabase.create_client before core.database is imported
from unittest.mock import MagicMock, patch

_mock_supabase_client = MagicMock()
patch("supabase.create_client", return_value=_mock_supabase_client).start()

import pytest
from datetime import datetime, timedelta, timezone
from unittest.mock import MagicMock

from httpx import ASGITransport, AsyncClient


# ─── User fixture data ───────────────────────────────────────────────

FAKE_USER_ID = "11111111-1111-1111-1111-111111111111"
FAKE_PASSWORD_HASH = "$argon2id$v=19$m=65536,t=3,p=4$fakesalt$fakehash"


@pytest.fixture
def fake_user_dict():
    return {
        "id": FAKE_USER_ID,
        "first_name": "John",
        "last_name": "Doe",
        "email": "john@example.com",
        "password_hash": FAKE_PASSWORD_HASH,
        "is_verified": True,
        "verification_token": None,
        "verification_token_expires_at": None,
        "pending_email": None,
        "reset_token": None,
        "reset_token_expires_at": None,
    }


@pytest.fixture
def fake_unverified_user_dict(fake_user_dict):
    return {
        **fake_user_dict,
        "is_verified": False,
        "verification_token": "verify-token-123",
        "verification_token_expires_at": (
            datetime.now(timezone.utc) + timedelta(hours=24)
        ).isoformat(),
    }


@pytest.fixture
def fake_user_with_pending_email(fake_user_dict):
    return {
        **fake_user_dict,
        "pending_email": "newemail@example.com",
        "verification_token": "email-change-token-456",
        "verification_token_expires_at": (
            datetime.now(timezone.utc) + timedelta(hours=24)
        ).isoformat(),
    }


@pytest.fixture
def fake_user_with_reset_token(fake_user_dict):
    return {
        **fake_user_dict,
        "reset_token": "reset-token-789",
        "reset_token_expires_at": (
            datetime.now(timezone.utc) + timedelta(hours=1)
        ).isoformat(),
    }


@pytest.fixture
def fake_user_with_expired_reset_token(fake_user_dict):
    return {
        **fake_user_dict,
        "reset_token": "expired-reset-token",
        "reset_token_expires_at": (
            datetime.now(timezone.utc) - timedelta(hours=1)
        ).isoformat(),
    }


# ─── Mock AuthRepository ─────────────────────────────────────────────

@pytest.fixture
def mock_auth_repo():
    repo = MagicMock()
    repo.get_user_by_email.return_value = None
    repo.get_user_by_id.return_value = None
    repo.get_user_by_verification_token.return_value = None
    repo.get_user_by_reset_token.return_value = None
    repo.create_user.return_value = {"id": FAKE_USER_ID}
    repo.update_user.return_value = {"id": FAKE_USER_ID}
    repo.update_verification_status.return_value = {"id": FAKE_USER_ID}
    repo.save_reset_token.return_value = {"id": FAKE_USER_ID}
    repo.update_password.return_value = {"id": FAKE_USER_ID}
    return repo


# ─── Auth service with mocked repo + email ───────────────────────────

@pytest.fixture
def auth_service(mock_auth_repo):
    with patch("services.auth.email_password.EmailSender") as MockEmailSender:
        MockEmailSender.return_value = MagicMock()
        from services.auth.email_password import EmailPasswordAuth

        service = EmailPasswordAuth(mock_auth_repo)
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


# ─── Supabase mock helper ────────────────────────────────────────────

def _build_supabase_mock(data):
    """Build a chained mock for supabase.table().select().eq().execute()"""
    mock_client = MagicMock()
    mock_execute = MagicMock()
    mock_execute.data = data

    mock_table = MagicMock()
    mock_table.select.return_value = mock_table
    mock_table.insert.return_value = mock_table
    mock_table.update.return_value = mock_table
    mock_table.eq.return_value = mock_table
    mock_table.execute.return_value = mock_execute

    mock_client.table.return_value = mock_table
    return mock_client, mock_table


# ─── FastAPI TestClient ──────────────────────────────────────────────

@pytest.fixture
def test_client(mock_auth_repo, fake_user_dict):
    from fastapi.testclient import TestClient
    from app import app
    from api.dependencies import get_auth_service, get_current_user
    from services.auth.email_password import EmailPasswordAuth

    with patch("services.auth.email_password.EmailSender") as MockEmailSender:
        MockEmailSender.return_value = MagicMock()
        service = EmailPasswordAuth(mock_auth_repo)

        app.dependency_overrides[get_auth_service] = lambda: service
        app.dependency_overrides[get_current_user] = lambda: fake_user_dict

        yield TestClient(app)

        app.dependency_overrides.clear()
