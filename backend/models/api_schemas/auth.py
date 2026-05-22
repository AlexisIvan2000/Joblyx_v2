import re

from pydantic import BaseModel, EmailStr, field_validator


class UserCreate(BaseModel):
    first_name: str
    last_name: str
    email: EmailStr
    password: str
    avatar_url: str | None = None

    @field_validator("password")
    @classmethod
    def validate_password(cls, v: str) -> str:
        if len(v) < 8:
            raise ValueError("Password must be at least 8 characters long")
        if not re.search(r'[!@#$%^&*(),.?":{}|<>_\-+=\[\]\\;\'`~]', v):
            raise ValueError("Password must contain at least 1 special character")
        return v


class UserLogin(BaseModel):
    email: EmailStr
    password: str


class LinkedInCallback(BaseModel):
    code: str


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"


class RefreshToken(BaseModel):
    refresh_token: str


class ForgotPassword(BaseModel):
    email: EmailStr


class ResetPassword(BaseModel):
    email: EmailStr
    code: str
    new_password: str


class VerifyEmail(BaseModel):
    email: EmailStr
    code: str


class VerifyEmailChange(BaseModel):
    code: str


class MessageResponse(BaseModel):
    message: str


class ResendVerification(BaseModel):
    email: EmailStr
