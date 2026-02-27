"""Tests for api/routers/users.py — user route HTTP layer."""

from unittest.mock import patch, MagicMock

import pytest

from tests.conftest import FAKE_USER_ID


class TestGetMe:
    def test_returns_user_without_password(self, test_client, fake_user_dict):
        resp = test_client.get("/users/me")
        assert resp.status_code == 200
        data = resp.json()
        assert data["email"] == fake_user_dict["email"]
        assert "password_hash" not in data

    def test_returns_200(self, test_client):
        resp = test_client.get("/users/me")
        assert resp.status_code == 200


class TestUpdateProfile:
    def test_success(self, test_client, mock_auth_repo, fake_user_dict):
        mock_auth_repo.update_user.return_value = fake_user_dict
        resp = test_client.put("/users/me", json={"first_name": "Jane"})
        assert resp.status_code == 200
        assert "updated" in resp.json()["message"].lower()

    def test_empty_body_returns_400(self, test_client):
        resp = test_client.put("/users/me", json={})
        assert resp.status_code == 400


class TestChangePassword:
    def test_success(self, test_client, mock_auth_repo, fake_user_dict):
        mock_auth_repo.get_user_by_id.return_value = fake_user_dict
        with patch("services.auth.email_password.Security") as MockSec:
            MockSec.verify_password.return_value = True
            MockSec.hash_password.return_value = "new-hash"
            resp = test_client.post("/users/me/change-password", json={
                "current_password": "OldPass1!",
                "new_password": "NewPass1!",
            })
        assert resp.status_code == 200

    def test_invalid_new_password_returns_422(self, test_client):
        resp = test_client.post("/users/me/change-password", json={
            "current_password": "old",
            "new_password": "short",
        })
        assert resp.status_code == 422


class TestChangeEmail:
    def test_success(self, test_client, mock_auth_repo, fake_user_dict):
        mock_auth_repo.get_user_by_id.return_value = fake_user_dict
        mock_auth_repo.get_user_by_email.return_value = None
        with patch("services.auth.email_password.Security") as MockSec:
            MockSec.verify_password.return_value = True
            resp = test_client.post("/users/me/change-email", json={
                "new_email": "new@example.com",
                "password": "Secure1!x",
            })
        assert resp.status_code == 200

    def test_invalid_email_returns_422(self, test_client):
        resp = test_client.post("/users/me/change-email", json={
            "new_email": "not-email",
            "password": "pass",
        })
        assert resp.status_code == 422


class TestResendEmailVerification:
    def test_no_pending_returns_400(self, test_client, mock_auth_repo, fake_user_dict):
        mock_auth_repo.get_user_by_id.return_value = fake_user_dict
        resp = test_client.post("/users/me/resend-email-verification")
        assert resp.status_code == 400
