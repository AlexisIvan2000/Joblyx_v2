from datetime import datetime, timedelta, timezone

import pytest
from argon2.exceptions import InvalidHashError

from core.security import Security



class TestHashPassword:
    def test_returns_string(self):
        result = Security.hash_password("Password1!")
        assert isinstance(result, str)

    def test_argon2_prefix(self):
        result = Security.hash_password("Password1!")
        assert result.startswith("$argon2")

    def test_different_hashes_each_call(self):
        h1 = Security.hash_password("Password1!")
        h2 = Security.hash_password("Password1!")
        assert h1 != h2




class TestVerifyPassword:
    def test_correct_password_returns_true(self):
        hashed = Security.hash_password("MySecure1!")
        assert Security.verify_password(hashed, "MySecure1!") is True

    def test_wrong_password_returns_false(self):
        hashed = Security.hash_password("MySecure1!")
        assert Security.verify_password(hashed, "WrongPass1!") is False

    def test_garbage_hash_raises(self):
        with pytest.raises(InvalidHashError):
            Security.verify_password("not-a-hash", "anything")



class TestCreateAccessToken:
    def test_contains_sub(self):
        token = Security.create_access_token("user-123")
        payload = Security.decode_token(token)
        assert payload["sub"] == "user-123"

    def test_type_is_access(self):
        token = Security.create_access_token("user-123")
        payload = Security.decode_token(token)
        assert payload["type"] == "access"

    def test_exp_approx_60_min(self):
        token = Security.create_access_token("user-123")
        payload = Security.decode_token(token)
        exp = datetime.fromtimestamp(payload["exp"], tz=timezone.utc)
        now = datetime.now(timezone.utc)
        delta = exp - now
        assert timedelta(minutes=55) < delta < timedelta(minutes=65)



class TestCreateRefreshToken:
    def test_type_is_refresh(self):
        token = Security.create_refresh_token("user-123")
        payload = Security.decode_token(token)
        assert payload["type"] == "refresh"

    def test_exp_approx_30_days(self):
        token = Security.create_refresh_token("user-123")
        payload = Security.decode_token(token)
        exp = datetime.fromtimestamp(payload["exp"], tz=timezone.utc)
        now = datetime.now(timezone.utc)
        delta = exp - now
        assert timedelta(days=29) < delta < timedelta(days=31)




class TestDecodeToken:
    def test_valid_token_returns_dict(self):
        token = Security.create_access_token("user-123")
        payload = Security.decode_token(token)
        assert isinstance(payload, dict)
        assert payload["sub"] == "user-123"

    def test_garbage_token_returns_none(self):
        assert Security.decode_token("garbage.token.value") is None

    def test_wrong_secret_returns_none(self, monkeypatch):
        token = Security.create_access_token("user-123")
        monkeypatch.setattr("core.security.JWT_SECRET_KEY", "wrong-secret")
        assert Security.decode_token(token) is None
