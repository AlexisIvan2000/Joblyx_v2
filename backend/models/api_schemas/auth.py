from pydantic import BaseModel, EmailStr


class UserCreate(BaseModel):
    first_name: str
    last_name: str
    email: EmailStr
    password: str
    avatar_url: str | None = None


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
