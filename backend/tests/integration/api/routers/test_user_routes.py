import pytest

from unittest.mock import patch, MagicMock
from tests.conftest import FAKE_USER_ID, FAKE_OTP_CODE, FAKE_OTP_HASH, _make_user_obj


class TestGetMe:
    def test_returns_user_without_password(self, test_client):
        resp = test_client.get("/users/me")
        assert resp.status_code == 200
        data = resp.json()
        assert data["email"] == "john@example.com"
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
        with patch("services.users.users.Security") as MockSec:
            MockSec.verify_password.side_effect = [True, False]  # current=OK, same_check=different
            MockSec.hash_password.return_value = "new-hash"
            resp = test_client.post("/users/me/change-password", json={
                "current_password": "OldPass1!",
                "new_password": "NewPass1!",
            })
        assert resp.status_code == 200

    def test_invalid_new_password_returns_400(self, test_client):
       
        resp = test_client.post("/users/me/change-password", json={
            "current_password": "old",
            "new_password": "short",
        })
        assert resp.status_code == 400


class TestChangeEmail:
    def test_success(self, test_client, mock_auth_repo, fake_user_dict):
        mock_auth_repo.get_user_by_id.return_value = fake_user_dict
        mock_auth_repo.get_user_by_email.return_value = None
        with patch("services.users.users.Security") as MockSec:
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


class TestConfirmEmailChange:
    def test_success(self, test_client, mock_auth_repo, fake_user_with_pending_email):
        mock_auth_repo.get_user_by_id.return_value = fake_user_with_pending_email
        with patch("services.users.users.Security") as MockSec:
            MockSec.hash_token.return_value = FAKE_OTP_HASH
            resp = test_client.post("/users/me/confirm-email-change", json={"code": FAKE_OTP_CODE})
        assert resp.status_code == 200
        assert "changed" in resp.json()["message"].lower()

    def test_invalid_code_returns_400(self, test_client, mock_auth_repo, fake_user_with_pending_email):
        mock_auth_repo.get_user_by_id.return_value = fake_user_with_pending_email
        with patch("services.users.users.Security") as MockSec:
            MockSec.hash_token.return_value = "wrong-hash"
            resp = test_client.post("/users/me/confirm-email-change", json={"code": "000000"})
        assert resp.status_code == 400


class TestResendEmailVerification:
    def test_no_pending_returns_400(self, test_client, mock_auth_repo, fake_user_dict):
        mock_auth_repo.get_user_by_id.return_value = fake_user_dict
        resp = test_client.post("/users/me/resend-email-verification")
        assert resp.status_code == 400


class TestSetPassword:
    def test_success_for_linkedin_account(self, test_client, mock_auth_repo):
        
        from app import app
        from api.v1.client.dependencies import get_current_user

        linkedin_user = _make_user_obj(password_hash=None, linkedin_id="linkedin123")
        mock_auth_repo.get_user_by_id.return_value = linkedin_user

        async def override():
            return linkedin_user

        app.dependency_overrides[get_current_user] = override

        with patch("services.users.users.Security") as MockSec:
            MockSec.hash_password.return_value = "newhash"
            resp = test_client.post("/users/me/set-password", json={"new_password": "Test@123!"})

        assert resp.status_code == 200

    def test_fails_if_already_has_password(self, test_client, mock_auth_repo, fake_user_dict):
        
        mock_auth_repo.get_user_by_id.return_value = fake_user_dict
        resp = test_client.post("/users/me/set-password", json={"new_password": "Test@123!"})
        assert resp.status_code == 409


class TestGetMeHasPassword:
    def test_returns_has_password_field(self, test_client):
       
        resp = test_client.get("/users/me")
        assert resp.status_code == 200
        data = resp.json()
        assert "has_password" in data
        assert data["has_password"] is True
