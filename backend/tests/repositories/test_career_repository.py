# Tests for repositories/career_repository.py — async stub.

from unittest.mock import AsyncMock

import pytest

from repositories.career_repository import CareerRepository


@pytest.fixture
def mock_session():
    return AsyncMock()


@pytest.fixture
def repo(mock_session):
    return CareerRepository(mock_session)


class TestCareerRepositoryStubs:
    @pytest.mark.asyncio
    async def test_get_career_profile_raises(self, repo):
        with pytest.raises(NotImplementedError):
            await repo.get_career_profile_by_user_id("u-1")

    @pytest.mark.asyncio
    async def test_create_career_profile_raises(self, repo):
        with pytest.raises(NotImplementedError):
            await repo.create_career_profile({})

    @pytest.mark.asyncio
    async def test_create_user_skills_raises(self, repo):
        with pytest.raises(NotImplementedError):
            await repo.create_user_skills([])

    @pytest.mark.asyncio
    async def test_create_roadmap_raises(self, repo):
        with pytest.raises(NotImplementedError):
            await repo.create_roadmap({})

    @pytest.mark.asyncio
    async def test_get_roadmap_raises(self, repo):
        with pytest.raises(NotImplementedError):
            await repo.get_roadmap_by_user_id("u-1")

    @pytest.mark.asyncio
    async def test_get_user_skills_raises(self, repo):
        with pytest.raises(NotImplementedError):
            await repo.get_user_skills_by_user_id("u-1")
