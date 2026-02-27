"""Tests for api/routers/auth.py — auth route HTTP layer."""

from unittest.mock import patch, MagicMock

import pytest
from fastapi import HTTPException

from tests.conftest import FAKE_USER_ID


class TestRegisterRoute:
    def test_success(self, test_client, mock_auth_repo):
        mock_auth_repo.get_user_by_email.return_value = None
        with patch("services.auth.email_password.Security") as MockSec:
            MockSec.hash_password.return_value = "hashed"
            MockSec.create_access_token.return_value = "at"
            MockSec.create_refresh_token.return_value = "rt"
            resp = test_client.post("/auth/register", json={
                "first_name": "John",
                "last_name": "Doe",
                "email": "john@example.com",
                "password": "Secure1!x",
            })
        assert resp.status_code == 200
        data = resp.json()
        assert "access_token" in data
        assert "refresh_token" in data

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
    def test_invalid_token_returns_400(self, test_client, mock_auth_repo):
        mock_auth_repo.get_user_by_verification_token.return_value = None
        resp = test_client.post("/auth/verify-email", json={"token": "bad"})
        assert resp.status_code == 400


class TestRefreshRoute:
    def test_success(self, test_client):
        with patch("services.auth.email_password.Security") as MockSec:
            MockSec.decode_token.return_value = {"sub": FAKE_USER_ID, "type": "refresh"}
            MockSec.create_access_token.return_value = "new-at"
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
    def test_invalid_token_returns_400(self, test_client, mock_auth_repo):
        mock_auth_repo.get_user_by_reset_token.return_value = None
        resp = test_client.post("/auth/reset-password", json={
            "token": "bad",
            "new_password": "NewPass1!",
        })
        assert resp.status_code == 400
