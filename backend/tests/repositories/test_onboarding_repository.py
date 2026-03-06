"""Tests for repositories/onboarding_repository.py — unit tests with mocked session."""

from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from repositories.onboarding_repository import OnboardingRepository
from tests.conftest import FAKE_USER_ID


@pytest.fixture
def mock_session():
    session = AsyncMock()
    session.add = MagicMock()
    session.add_all = MagicMock()
    return session


@pytest.fixture
def repo(mock_session):
    return OnboardingRepository(mock_session)


class TestCreateCareer:
    @pytest.mark.asyncio
    async def test_adds_and_flushes(self, repo, mock_session):
        data = {"level": "junior", "city": "Montreal", "province": "QC"}
        await repo.create_career(FAKE_USER_ID, data)

        mock_session.add.assert_called_once()
        mock_session.flush.assert_called_once()

    @pytest.mark.asyncio
    async def test_sets_onboarding_completed(self, repo, mock_session):
        data = {"level": "junior", "city": "Montreal", "province": "QC"}
        career = await repo.create_career(FAKE_USER_ID, data)

        added_obj = mock_session.add.call_args[0][0]
        assert added_obj.onboarding_completed is True
        assert added_obj.user_id == FAKE_USER_ID


class TestCreateUserSkills:
    @pytest.mark.asyncio
    async def test_adds_all_and_flushes(self, repo, mock_session):
        skills = [
            {"skill_name": "Python", "category": "Programming", "proficiency": "advanced"},
            {"skill_name": "SQL", "category": "Database", "proficiency": "intermediate"},
        ]
        await repo.create_user_skills(FAKE_USER_ID, skills)

        mock_session.add_all.assert_called_once()
        added = mock_session.add_all.call_args[0][0]
        assert len(added) == 2
        assert added[0].user_id == FAKE_USER_ID
        assert added[1].skill_name == "SQL"
        mock_session.flush.assert_called_once()


class TestGetCareerByUserId:
    @pytest.mark.asyncio
    async def test_executes_query(self, repo, mock_session):
        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = None
        mock_session.execute.return_value = mock_result

        result = await repo.get_career_by_user_id(FAKE_USER_ID)

        assert result is None
        mock_session.execute.assert_called_once()


class TestGetSkillsByUserId:
    @pytest.mark.asyncio
    async def test_executes_query(self, repo, mock_session):
        mock_result = MagicMock()
        mock_result.scalars.return_value.all.return_value = []
        mock_session.execute.return_value = mock_result

        result = await repo.get_skills_by_user_id(FAKE_USER_ID)

        assert result == []
        mock_session.execute.assert_called_once()


class TestUpdateCareer:
    @pytest.mark.asyncio
    async def test_updates_and_returns(self, repo, mock_session):
        mock_career = MagicMock(level="mid")
        mock_result = MagicMock()
        mock_result.scalar_one.return_value = mock_career
        mock_session.execute.return_value = mock_result

        result = await repo.update_career(FAKE_USER_ID, {"level": "mid"})

        assert mock_session.execute.call_count == 2  # UPDATE + SELECT
        assert mock_session.flush.call_count == 1


class TestDeleteSkillsByUserId:
    @pytest.mark.asyncio
    async def test_deletes_and_flushes(self, repo, mock_session):
        await repo.delete_skills_by_user_id(FAKE_USER_ID)

        mock_session.execute.assert_called_once()
        mock_session.flush.assert_called_once()


class TestHasProfile:
    @pytest.mark.asyncio
    async def test_returns_true_when_completed(self, repo, mock_session):
        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = True
        mock_session.execute.return_value = mock_result

        assert await repo.has_profile(FAKE_USER_ID) is True

    @pytest.mark.asyncio
    async def test_returns_false_when_no_career(self, repo, mock_session):
        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = None
        mock_session.execute.return_value = mock_result

        assert await repo.has_profile(FAKE_USER_ID) is False
