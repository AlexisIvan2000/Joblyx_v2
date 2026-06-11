from pydantic import BaseModel, EmailStr


class UpdateProfile(BaseModel):
    first_name: str | None = None
    last_name: str | None = None
    avatar_url: str | None = None


class ChangePassword(BaseModel):
    current_password: str
    new_password: str


class SetPassword(BaseModel):
    new_password: str


class ChangeEmail(BaseModel):
    new_email: EmailStr
    password: str
