"""Tests for api/routers/auth.py — auth route HTTP layer."""

from unittest.mock import patch, MagicMock

import pytest
from fastapi import HTTPException

from tests.conftest import FAKE_USER_ID, FAKE_OTP_CODE, FAKE_OTP_HASH


class TestRegisterRoute:
    def test_success_returns_message(self, test_client, mock_auth_repo):
        mock_auth_repo.get_user_by_email.return_value = None
        with patch("services.auth.email_password.Security") as MockSec:
            MockSec.hash_password.return_value = "hashed"
            resp = test_client.post("/auth/register", json={
                "first_name": "John",
                "last_name": "Doe",
                "email": "john@example.com",
                "password": "Secure1!x",
            })
        assert resp.status_code == 200
        data = resp.json()
        assert "message" in data
        assert "access_token" not in data

    def test_invalid_body_returns_422(self, test_client):
        resp = test_client.post("/auth/register", json={
            "first_name": "John",
            "last_name": "Doe",
            "email": "bad-email",
            "password": "Secure1!x",
        })
        assert resp.status_code == 422


class TestLoginRoute:
    def test_success(self, test_client, mock_auth_repo, fake_user_dict):
        mock_auth_repo.get_user_by_email.return_value = fake_user_dict
        with patch("services.auth.email_password.Security") as MockSec:
            MockSec.verify_password.return_value = True
            MockSec.create_access_token.return_value = "at"
            MockSec.create_refresh_token.return_value = "rt"
            MockSec.hash_token.return_value = "hashed-rt"
            resp = test_client.post("/auth/login", json={
                "email": "john@example.com",
                "password": "Secure1!x",
            })
        assert resp.status_code == 200

    def test_wrong_credentials_returns_401(self, test_client, mock_auth_repo):
        mock_auth_repo.get_user_by_email.return_value = None
        resp = test_client.post("/auth/login", json={
            "email": "john@example.com",
            "password": "wrong",
        })
        assert resp.status_code == 401


class TestVerifyEmailRoute:
    def test_invalid_request_returns_400(self, test_client, mock_auth_repo):
        mock_auth_repo.get_user_by_email.return_value = None
        resp = test_client.post("/auth/verify-email", json={"email": "john@example.com", "code": "123456"})
        assert resp.status_code == 400


class TestRefreshRoute:
    def test_success(self, test_client, mock_refresh_token_repo):
        mock_refresh_token_repo.get_by_token_hash.return_value = MagicMock()
        with patch("services.auth.email_password.Security") as MockSec:
            MockSec.decode_token.return_value = {"sub": FAKE_USER_ID, "type": "refresh"}
            MockSec.hash_token.return_value = "hashed-rt"
            MockSec.create_access_token.return_value = "new-at"
            MockSec.create_refresh_token.return_value = "new-rt"
            resp = test_client.post("/auth/refresh", json={"refresh_token": "valid-rt"})
        assert resp.status_code == 200
        assert resp.json()["access_token"] == "new-at"

    def test_invalid_refresh_returns_401(self, test_client):
        with patch("services.auth.email_password.Security") as MockSec:
            MockSec.decode_token.return_value = None
            resp = test_client.post("/auth/refresh", json={"refresh_token": "bad"})
        assert resp.status_code == 401


class TestForgotPasswordRoute:
    def test_always_200(self, test_client, mock_auth_repo):
        mock_auth_repo.get_user_by_email.return_value = None
        resp = test_client.post("/auth/forgot-password", json={"email": "any@example.com"})
        assert resp.status_code == 200


class TestResetPasswordRoute:
    def test_no_user_returns_400(self, test_client, mock_auth_repo):
        mock_auth_repo.get_user_by_email.return_value = None
        resp = test_client.post("/auth/reset-password", json={
            "email": "bad@example.com",
            "code": "123456",
            "new_password": "NewPass1!",
        })
        assert resp.status_code == 400
