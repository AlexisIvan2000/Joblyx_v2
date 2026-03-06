import re
from enum import Enum
from typing import List
from pydantic import BaseModel, EmailStr, field_validator

class UserCreate(BaseModel):
    first_name: str
    last_name: str
    email: EmailStr
    password: str
    avatar_url: str | None = None

    @field_validator('password')
    @classmethod
    def validate_password(cls, v: str) -> str:
        if len(v) < 8:
            raise ValueError('Password must be at least 8 characters long')
        if not re.search(r'[!@#$%^&*(),.?":{}|<>_\-+=\[\]\\;\'`~]', v):
            raise ValueError('Password must contain at least 1 special character')
        return v
    


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


class SkillLevel(str, Enum):
    beginner = "beginner"
    intermediate = "intermediate"
    advanced = "advanced"

class UserLevel(str, Enum):
    junior = "junior"
    mid = "mid"
    reconversion = "reconversion"

class Language(str, Enum):
    fr = "fr"
    en = "en"
    bilingual = "bilingual"


class UserSkillCreate(BaseModel):
    skill_name: str
    category: str
    level: SkillLevel

    @field_validator("skill_name")
    @classmethod
    def validate_skill_name(cls, v: str) -> str:
        v = v.strip()
        if not v:
            raise ValueError("skill_name must not be empty")
        return v

    @field_validator("category")
    @classmethod
    def validate_category(cls, v: str) -> str:
        v = v.strip()
        if not v:
            raise ValueError("category must not be empty")
        return v


class OnboardingRequest(BaseModel):
    level: UserLevel
    years_experience: int
    target_jobs: List[str]
    city: str
    province: str
    language: Language
    skills: List[UserSkillCreate]

    @field_validator("years_experience")
    @classmethod
    def validate_years_experience(cls, v: int) -> int:
        if v < 0 or v > 50:
            raise ValueError("years_experience must be between 0 and 50")
        return v

    @field_validator("target_jobs")
    @classmethod
    def validate_target_jobs(cls, v: List[str]) -> List[str]:
        v = [job.strip() for job in v]
        v = [job for job in v if job]
        if len(v) == 0:
            raise ValueError("At least one target job is required")
        if len(v) > 3:
            raise ValueError("Maximum 3 target jobs allowed")
        return v

    @field_validator("skills")
    @classmethod
    def validate_skills(cls, v: list) -> list:
        if len(v) == 0:
            raise ValueError("At least one skill is required")
        return v


class OnboardingResponse(BaseModel):
    message: str
    roadmap_id: str