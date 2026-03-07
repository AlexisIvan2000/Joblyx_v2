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
    senior = "senior"
    reconversion = "reconversion"

class Language(str, Enum):
    fr = "fr"
    en = "en"
    bilingual = "bilingual"


class SkillItem(BaseModel):
    skill_name: str
    category: str
    proficiency: SkillLevel

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
    previous_field: str | None = None
    skills: List[SkillItem]

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
    level: UserLevel
    years_experience: int
    target_jobs: List[str]
    city: str
    province: str
    language: Language
    previous_field: str | None = None
    skills: List[SkillItem]
    onboarding_completed: bool


class OnboardingStatus(BaseModel):
    has_profile: bool


# ─── Roadmap schemas ───────────────────────────────────────────────

class RoadmapGenerateResponse(BaseModel):
    status: str

class RoadmapStatusResponse(BaseModel):
    generation_status: str
    has_roadmap: bool

class RoadmapResource(BaseModel):
    title: str
    url: str
    type: str
    free: bool

class RoadmapSkill(BaseModel):
    name: str
    priority: str

class RoadmapPhase(BaseModel):
    title: str
    duration_weeks: int
    skills: List[RoadmapSkill]
    actions: List[str]
    resources: List[RoadmapResource]
    certifications: List[str] = []
    milestone: str

class RoadmapResponse(BaseModel):
    id: str
    target_jobs: List[str]
    phases: List[RoadmapPhase]
    status: str
    created_at: str | None = None

class RoadmapHistoryItem(BaseModel):
    id: str
    target_jobs: List[str]
    status: str
    created_at: str | None = None


# ─── Application schemas ──────────────────────────────────────────

class ApplicationStatus(str, Enum):
    applied = "applied"
    phone_screen = "phone_screen"
    technical = "technical"
    final_interview = "final_interview"
    offer = "offer"
    accepted = "accepted"
    rejected = "rejected"
    withdrawn = "withdrawn"

class ApplicationCreate(BaseModel):
    company_name: str
    job_title: str
    job_url: str | None = None
    job_description: str | None = None
    status: ApplicationStatus = ApplicationStatus.applied
    notes: str | None = None

    @field_validator("company_name", "job_title")
    @classmethod
    def validate_not_empty(cls, v: str) -> str:
        v = v.strip()
        if not v:
            raise ValueError("This field must not be empty")
        return v

class ApplicationUpdate(BaseModel):
    company_name: str | None = None
    job_title: str | None = None
    job_url: str | None = None
    job_description: str | None = None
    status: ApplicationStatus | None = None
    notes: str | None = None

class ApplicationResponse(BaseModel):
    id: str
    company_name: str
    job_title: str
    job_url: str | None = None
    job_description: str | None = None
    status: str
    cv_file_key: str | None = None
    cv_url: str | None = None
    notes: str | None = None
    applied_at: str | None = None
    updated_at: str | None = None