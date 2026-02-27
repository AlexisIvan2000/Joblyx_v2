import re
from pydantic import BaseModel, EmailStr, field_validator

class UserCreate(BaseModel):
    first_name: str
    last_name: str
    email: EmailStr
    password: str

    @field_validator('password')
    @classmethod
    def validate_password(cls, v: str) -> str:
        if len(v) < 8:
            raise ValueError('Password must be at least 8 characters long')
        if not re.search(r'[!@#$%^&*(),.?":{}|<>_\-+=\[\]\\;\'`~]', v):
            raise ValueError('Password must contain at least 1 special character')
        return v
    
    avatar_url: str

class UserLogin(BaseModel):
    email: EmailStr
    password: str

class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"

class RefreshToken(BaseModel):
    refresh_token: str

class ForgotPassword(BaseModel):
    email: EmailStr

class ResetPassword(BaseModel):
    token: str
    new_password: str

class VerifyEmail(BaseModel):
    token: str

class ResendVerification(BaseModel):
    email: EmailStr

class UpdateProfile(BaseModel):
    first_name: str | None = None
    last_name: str | None = None
    avatar_url: str | None = None

class ChangePassword(BaseModel):
    current_password: str
    new_password: str

    @field_validator('new_password')
    @classmethod
    def validate_password(cls, v: str) -> str:
        if len(v) < 8:
            raise ValueError('Password must be at least 8 characters long')
        if not re.search(r'[!@#$%^&*(),.?":{}|<>_\-+=\[\]\\;\'`~]', v):
            raise ValueError('Password must contain at least 1 special character')
        return v

class ChangeEmail(BaseModel):
    new_email: EmailStr
    password: str
