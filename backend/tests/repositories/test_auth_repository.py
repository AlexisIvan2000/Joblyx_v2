"""Tests for repositories/auth_repository.py — Supabase data access."""

from unittest.mock import MagicMock

import pytest

from repositories.auth_repository import AuthRepository


# ─── Helpers ──────────────────────────────────────────────────────────

def _make_repo_and_client(data=None):
    """Return (repo, mock_client, mock_chain) with chained table mock."""
    mock_client = MagicMock()

    mock_execute = MagicMock()
    mock_execute.data = data if data is not None else []

    mock_chain = MagicMock()
    mock_chain.select.return_value = mock_chain
    mock_chain.insert.return_value = mock_chain
    mock_chain.update.return_value = mock_chain
    mock_chain.eq.return_value = mock_chain
    mock_chain.execute.return_value = mock_execute

    mock_client.table.return_value = mock_chain

    return AuthRepository(mock_client), mock_client, mock_chain


# ─── get_user_by_email ────────────────────────────────────────────────

class TestGetUserByEmail:
    def test_found(self, fake_user_dict):
        repo, client, chain = _make_repo_and_client([fake_user_dict])
        result = repo.get_user_by_email("john@example.com")
        assert result == fake_user_dict
        chain.eq.assert_called_with("email", "john@example.com")

    def test_not_found(self):
        repo, _, _ = _make_repo_and_client([])
        assert repo.get_user_by_email("nope@example.com") is None


# ─── get_user_by_id ──────────────────────────────────────────────────

class TestGetUserById:
    def test_found(self, fake_user_dict):
        repo, _, chain = _make_repo_and_client([fake_user_dict])
        result = repo.get_user_by_id("11111111-1111-1111-1111-111111111111")
        assert result == fake_user_dict
        chain.eq.assert_called_with("id", "11111111-1111-1111-1111-111111111111")

    def test_not_found(self):
        repo, _, _ = _make_repo_and_client([])
        assert repo.get_user_by_id("nonexistent") is None


# ─── create_user ──────────────────────────────────────────────────────

class TestCreateUser:
    def test_returns_created_user(self, fake_user_dict):
        repo, _, chain = _make_repo_and_client([fake_user_dict])
        result = repo.create_user({"email": "john@example.com"})
        assert result == fake_user_dict
        chain.insert.assert_called_once_with({"email": "john@example.com"})


# ─── update_user ──────────────────────────────────────────────────────

class TestUpdateUser:
    def test_calls_update_and_eq(self, fake_user_dict):
        repo, _, chain = _make_repo_and_client([fake_user_dict])
        data = {"first_name": "Jane"}
        repo.update_user("user-1", data)
        chain.update.assert_called_once_with(data)
        chain.eq.assert_called_with("id", "user-1")


# ─── get_user_by_verification_token ──────────────────────────────────

class TestGetUserByVerificationToken:
    def test_found(self, fake_unverified_user_dict):
        repo, _, chain = _make_repo_and_client([fake_unverified_user_dict])
        result = repo.get_user_by_verification_token("verify-token-123")
        assert result == fake_unverified_user_dict
        chain.eq.assert_called_with("verification_token", "verify-token-123")

    def test_not_found(self):
        repo, _, _ = _make_repo_and_client([])
        assert repo.get_user_by_verification_token("bad-token") is None


# ─── update_verification_status ───────────────────────────────────────

class TestUpdateVerificationStatus:
    def test_calls_update_with_correct_data(self, fake_user_dict):
        repo, _, chain = _make_repo_and_client([fake_user_dict])
        repo.update_verification_status("user-1")
        chain.update.assert_called_once_with({
            "is_verified": True,
            "verification_token": None,
            "verification_token_expires_at": None,
        })


# ─── save_reset_token ────────────────────────────────────────────────

class TestSaveResetToken:
    def test_calls_update_with_token_and_expiry(self, fake_user_dict):
        repo, _, chain = _make_repo_and_client([fake_user_dict])
        repo.save_reset_token("john@example.com", "tok", "2026-01-01T00:00:00")
        chain.update.assert_called_once_with({
            "reset_token": "tok",
            "reset_token_expires_at": "2026-01-01T00:00:00",
        })
        chain.eq.assert_called_with("email", "john@example.com")


# ─── get_user_by_reset_token ─────────────────────────────────────────

class TestGetUserByResetToken:
    def test_found(self, fake_user_with_reset_token):
        repo, _, chain = _make_repo_and_client([fake_user_with_reset_token])
        result = repo.get_user_by_reset_token("reset-token-789")
        assert result == fake_user_with_reset_token
        chain.eq.assert_called_with("reset_token", "reset-token-789")

    def test_not_found(self):
        repo, _, _ = _make_repo_and_client([])
        assert repo.get_user_by_reset_token("nope") is None


# ─── update_password ──────────────────────────────────────────────────

class TestUpdatePassword:
    def test_calls_update_with_hash_and_clears_token(self, fake_user_dict):
        repo, _, chain = _make_repo_and_client([fake_user_dict])
        repo.update_password("user-1", "new-hash")
        chain.update.assert_called_once_with({
            "password_hash": "new-hash",
            "reset_token": None,
            "reset_token_expires_at": None,
        })
