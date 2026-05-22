"""DTOs pour le dashboard admin (/v1/admin/*)."""

from pydantic import BaseModel


# Listing & détail user


class AdminUserSummary(BaseModel):
    id: str
    first_name: str
    last_name: str
    email: str
    is_verified: bool
    is_active: bool
    has_linkedin: bool
    role: str
    is_founder: bool = False
    created_at: str
    last_active: str | None
    roadmaps_count: int
    applications_count: int
    coach_sessions_count: int
    interview_sessions_count: int


class AdminUserListResponse(BaseModel):
    users: list[AdminUserSummary]
    total: int
    page: int
    page_size: int


class AdminCareerSummary(BaseModel):
    level: str
    years_experience: int | None
    target_jobs: list[str] | None
    city: str
    province: str
    language: str | None
    previous_field: str | None
    generation_status: str | None
    regeneration_count: int


class AdminSkillSummary(BaseModel):
    skill_name: str
    category: str
    proficiency: str


class AdminRoadmapSummary(BaseModel):
    id: str
    status: str
    phase_count: int
    completed_phase_count: int
    created_at: str | None


class AdminApplicationSummary(BaseModel):
    id: str
    company_name: str
    job_title: str
    status: str
    has_cv: bool
    applied_at: str | None


class AdminCoachSessionSummary(BaseModel):
    id: str
    job_title: str | None
    company_name: str | None
    compatibility_score: int | None
    created_at: str | None


class AdminInterviewSessionSummary(BaseModel):
    id: str
    job_title: str
    company_name: str | None
    status: str
    overall_score: int | None
    created_at: str | None


class AdminUserUsage(BaseModel):
    coach_usage_count: int
    interview_usage_count: int
    regeneration_count: int


class AdminUserDetailResponse(BaseModel):
    id: str
    first_name: str
    last_name: str
    email: str
    is_verified: bool
    is_active: bool
    has_linkedin: bool
    avatar_url: str | None
    role: str
    is_founder: bool = False
    deactivated_at: str | None
    deactivation_reason: str | None
    admin_notes: str | None
    created_at: str
    last_active: str | None
    career: AdminCareerSummary | None
    skills: list[AdminSkillSummary]
    active_roadmap: AdminRoadmapSummary | None
    applications: list[AdminApplicationSummary]
    coach_history: list[AdminCoachSessionSummary]
    interview_history: list[AdminInterviewSessionSummary]
    usage: AdminUserUsage


# Actions


class AdminStatusRequest(BaseModel):
    is_active: bool
    reason: str | None = None


class AdminNotesRequest(BaseModel):
    notes: str | None = None


class AdminEmailRequest(BaseModel):
    subject: str
    body: str


class AdminUserActionResponse(BaseModel):
    id: str
    is_active: bool
    deactivated_at: str | None
    deactivation_reason: str | None
    message: str


# Stats


class AdminStatsResponse(BaseModel):
    total_users: int
    verified_users: int
    active_users_week: int
    total_roadmaps: int
    ai_roadmaps: int
    manual_roadmaps: int
    coach_sessions_month: int
    interview_sessions_month: int
    total_applications: int
    openai_usage_estimate_usd: float


class AdminRegistrationPoint(BaseModel):
    date: str
    count: int


# Audit log


class AdminAuditLogEntry(BaseModel):
    id: str
    admin_user_id: str | None
    action: str
    target_type: str | None
    target_id: str | None
    payload: dict | None
    created_at: str


class AdminAuditLogResponse(BaseModel):
    entries: list[AdminAuditLogEntry]
    total: int
    page: int
    page_size: int
