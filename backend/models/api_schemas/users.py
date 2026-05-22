import re

from pydantic import BaseModel, EmailStr, field_validator


class UpdateProfile(BaseModel):
    first_name: str | None = None
    last_name: str | None = None
    avatar_url: str | None = None


class ChangePassword(BaseModel):
    current_password: str
    new_password: str

    @field_validator("new_password")
    @classmethod
    def validate_password(cls, v: str) -> str:
        if len(v) < 8:
            raise ValueError("Password must be at least 8 characters long")
        if not re.search(r'[!@#$%^&*(),.?":{}|<>_\-+=\[\]\\;\'`~]', v):
            raise ValueError("Password must contain at least 1 special character")
        return v


class SetPassword(BaseModel):
    new_password: str

    @field_validator("new_password")
    @classmethod
    def validate_password(cls, v: str) -> str:
        if len(v) < 8:
            raise ValueError("Password must be at least 8 characters long")
        if not re.search(r'[!@#$%^&*(),.?":{}|<>_\-+=\[\]\\;\'`~]', v):
            raise ValueError("Password must contain at least 1 special character")
        return v


class ChangeEmail(BaseModel):
    new_email: EmailStr
    password: str
