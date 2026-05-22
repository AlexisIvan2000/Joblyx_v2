from enum import Enum
from typing import List

from pydantic import BaseModel, field_validator

from services.utils.job_title_validator import _ALLOWED_PATTERN, _IT_KEYWORDS, _MAX_LENGTH


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


class RoadmapGenerateRequest(BaseModel):
    """Données envoyées pour générer un roadmap avec l'IA."""
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
        for job in v:
            if len(job) > _MAX_LENGTH:
                raise ValueError(f"Job title too long (max {_MAX_LENGTH} characters)")
            if not _ALLOWED_PATTERN.match(job):
                raise ValueError("Job title contains invalid characters")
            if not any(kw in job.lower() for kw in _IT_KEYWORDS):
                raise ValueError(f"'{job}' must be related to IT/tech")
        return v

    @field_validator("skills")
    @classmethod
    def validate_skills(cls, v: list) -> list:
        if len(v) == 0:
            raise ValueError("At least one skill is required")
        return v


class CareerProfileResponse(BaseModel):
    level: str
    years_experience: int | None = None
    target_jobs: List[str] | None = None
    city: str
    province: str
    language: str | None = None
    previous_field: str | None = None
    skills: List[dict] = []


class CareerProfileUpdate(BaseModel):
    level: UserLevel | None = None
    years_experience: int | None = None
    target_jobs: List[str] | None = None
    city: str | None = None
    province: str | None = None
    language: Language | None = None
    previous_field: str | None = None
    skills: List[SkillItem] | None = None

    @field_validator("target_jobs")
    @classmethod
    def validate_target_jobs(cls, v: List[str] | None) -> List[str] | None:
        if v is None:
            return v
        for job in v:
            job = job.strip()
            if len(job) > _MAX_LENGTH:
                raise ValueError(f"Job title too long (max {_MAX_LENGTH} characters)")
            if not _ALLOWED_PATTERN.match(job):
                raise ValueError("Job title contains invalid characters")
            if not any(kw in job.lower() for kw in _IT_KEYWORDS):
                raise ValueError(f"'{job}' must be related to IT/tech")
        return v


class RoadmapGenerateResponse(BaseModel):
    status: str


class RoadmapStatusResponse(BaseModel):
    generation_status: str
    has_roadmap: bool


class RoadmapResource(BaseModel):
    title: str
    platform: str | None = None
    url: str | None = None
    type: str
    free: bool
    why: str | None = None


class RoadmapActionItem(BaseModel):
    task: str
    detail: str | None = None
    estimated_hours: int | None = None
    completed: bool = False


class RoadmapSkill(BaseModel):
    name: str
    priority: str
    reason: str | None = None
    completed: bool = False


class RoadmapCertification(BaseModel):
    name: str
    provider: str | None = None
    cost: str | None = None
    value: str | None = None


class RoadmapProject(BaseModel):
    name: str
    description: str | None = None
    technologies: List[str] = []
    portfolio_worthy: bool = False


class PhaseResponse(BaseModel):
    id: str
    phase_number: int
    title: str
    duration_weeks: int | None = None
    objective: str | None = None
    skills: list = []
    actions: list = []
    resources: list = []
    certifications: list = []
    projects: list = []
    milestone: str | None = None
    completed: bool = False
    custom: bool = False
    user_notes: str | None = None
    position: int = 0


class PhaseCreate(BaseModel):
    title: str
    duration_weeks: int | None = None
    objective: str | None = None
    skills: list = []
    actions: list = []
    resources: list = []
    certifications: list = []
    projects: list = []
    milestone: str | None = None
    user_notes: str | None = None
    position: int | None = None


class PhaseUpdate(BaseModel):
    title: str | None = None
    duration_weeks: int | None = None
    objective: str | None = None
    milestone: str | None = None
    user_notes: str | None = None
    skills: list | None = None
    actions: list | None = None
    resources: list | None = None
    certifications: list | None = None
    projects: list | None = None


class RoadmapCreate(BaseModel):
    phases: List[PhaseCreate]


class PhaseReorder(BaseModel):
    phase_ids: List[str]


class RoadmapResponse(BaseModel):
    id: str
    summary: dict | None = None
    phases: List[PhaseResponse]
    status: str
    created_at: str | None = None


class RoadmapHistoryItem(BaseModel):
    id: str
    summary: dict | None = None
    phases: List[PhaseResponse] = []
    status: str
    created_at: str | None = None


class RegenerationStatusResponse(BaseModel):
    used: int
    limit: int
    remaining: int
    resets_at: str
