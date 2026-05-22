from datetime import datetime
from enum import Enum

from pydantic import BaseModel, field_validator


class ApplicationStatus(str, Enum):
    saved = "saved"
    applied = "applied"
    online_assessment = "online_assessment"
    phone_screen = "phone_screen"
    technical = "technical"
    final_interview = "final_interview"
    offer = "offer"
    accepted = "accepted"
    rejected = "rejected"
    ghosted = "ghosted"
    withdrawn = "withdrawn"


class ApplicationCreate(BaseModel):
    company_name: str
    job_title: str
    job_url: str | None = None
    job_description: str | None = None
    status: ApplicationStatus = ApplicationStatus.saved
    notes: str | None = None
    applied_at: datetime | None = None

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
