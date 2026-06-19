import logging
from datetime import datetime, timedelta, timezone

from sqlalchemy.ext.asyncio import AsyncSession

from core.exceptions import CareerProfileRequired, RoadmapRegenerationLimitReached
from repositories.career_repository import CareerRepository

logger = logging.getLogger(__name__)

CACHE_MAX_AGE = timedelta(hours=48)
REGENERATION_LIMIT = 5


class CareerProfileService:
    def __init__(self, session: AsyncSession):
        self.session = session
        self.repo = CareerRepository(session)

    async def get_career(self, user_id: str):
        return await self.repo.get_by_user_id(user_id)

    async def get_skills(self, user_id: str) -> list[dict]:
        skills = await self.repo.get_skills(user_id)
        return [
            {"skill_name": s.skill_name, "category": s.category, "proficiency": s.proficiency}
            for s in skills
        ]

    async def get_market_data(self, target_jobs: list[str], city: str, province: str) -> list[dict] | None:
        if not target_jobs:
            return None
        cutoff = datetime.now(timezone.utc) - CACHE_MAX_AGE
        caches = await self.repo.get_market_skills(target_jobs, city, province, cutoff)

        all_skills: dict[str, dict] = {}
        for cache in caches:
            for skill in cache.top_skills:
                name = skill["name"]
                if name in all_skills:
                    all_skills[name]["count"] += skill.get("count", 0)
                else:
                    all_skills[name] = {**skill}

        if not all_skills:
            return None
        return sorted(all_skills.values(), key=lambda s: s.get("count", 0), reverse=True)

    async def save_career_and_skills(self, user_id: str, career_data: dict, skills_data: list[dict]) -> bool:
        is_first = await self.repo.upsert(user_id, career_data)
        await self.repo.replace_skills(user_id, skills_data)
        return is_first

    async def check_regeneration_limit(self, user_id: str) -> dict:
        now = datetime.now(timezone.utc)
        career = await self.get_career(user_id)
        if not career:
            return {"allowed": True, "used": 0, "remaining": REGENERATION_LIMIT, "resets_at": _next_month_reset(now).isoformat()}

        reset_at = career.regeneration_reset_at
        if reset_at is None or (now.year, now.month) != (reset_at.year, reset_at.month):
            await self.repo.reset_regeneration_counter(user_id, now)
            career = await self.get_career(user_id)

        used = career.regeneration_count or 0
        remaining = max(0, REGENERATION_LIMIT - used)

        return {
            "allowed": used < REGENERATION_LIMIT,
            "used": used,
            "remaining": remaining,
            "resets_at": _next_month_reset(now).isoformat(),
        }

    async def increment_regeneration_count(self, user_id: str) -> None:
        await self.repo.increment_regeneration_count(user_id)

    async def get_career_profile(self, user_id: str) -> dict:
        career = await self.get_career(user_id)
        if not career:
            raise CareerProfileRequired()
        skills = await self.get_skills(user_id)
        return {
            "level": career.level,
            "years_experience": career.years_experience,
            "target_jobs": career.target_jobs or [],
            "city": career.city,
            "province": career.province,
            "language": career.language,
            "previous_field": career.previous_field,
            "skills": skills,
        }

    async def update_career_profile(self, user_id: str, body) -> dict:
        career = await self.get_career(user_id)

        career_updates: dict = {}
        for field in ("level", "years_experience", "target_jobs", "city", "province", "language", "previous_field"):
            val = getattr(body, field, None)
            if val is not None:
                career_updates[field] = val.value if hasattr(val, "value") else val

        if not career:
            await self.repo.create(user_id, career_updates)
        elif career_updates:
            await self.repo.update_fields(user_id, career_updates)

        if body.skills is not None:
            skills_data = [
                {"skill_name": s.skill_name, "category": s.category, "proficiency": s.proficiency.value}
                for s in body.skills
            ]
            await self.repo.replace_skills(user_id, skills_data)

        await self.session.commit()
        return await self.get_career_profile(user_id)

    async def ensure_career_exists(self, user_id: str) -> None:
        career = await self.get_career(user_id)
        if not career:
            raise CareerProfileRequired()

    async def ensure_regeneration_allowed(self, user_id: str) -> None:
        regen = await self.check_regeneration_limit(user_id)
        if not regen["allowed"]:
            raise RoadmapRegenerationLimitReached(
                details={"remaining": 0, "resets_at": regen["resets_at"]},
            )

    async def get_regeneration_status(self, user_id: str) -> dict:
        regen = await self.check_regeneration_limit(user_id)
        return {
            "used": regen["used"],
            "limit": REGENERATION_LIMIT,
            "remaining": regen["remaining"],
            "resets_at": regen["resets_at"],
        }


def career_to_dict(career) -> dict:
    return {
        "level": career.level,
        "years_experience": career.years_experience,
        "target_jobs": career.target_jobs,
        "city": career.city,
        "province": career.province,
        "language": career.language,
        "previous_field": career.previous_field,
    }


def _next_month_reset(now: datetime) -> datetime:
    if now.month == 12:
        return datetime(now.year + 1, 1, 1, tzinfo=timezone.utc)
    return datetime(now.year, now.month + 1, 1, tzinfo=timezone.utc)
