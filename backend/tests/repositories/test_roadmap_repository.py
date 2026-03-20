"""Tests pour repositories/roadmap_repository.py."""

from unittest.mock import AsyncMock, MagicMock

import pytest

from repositories.roadmap_repository import RoadmapRepository
from tests.conftest import FAKE_USER_ID


@pytest.fixture
def mock_session():
    session = AsyncMock()
    session.flush = AsyncMock()
    session.delete = AsyncMock()
    return session


@pytest.fixture
def repo(mock_session):
    return RoadmapRepository(mock_session)


class TestCreateRoadmap:
    @pytest.mark.asyncio
    async def test_creates_roadmap_with_active_status(self, repo, mock_session):
        roadmap = await repo.create_roadmap(user_id=FAKE_USER_ID, summary={"overview": "Test"})
        mock_session.add.assert_called_once()
        mock_session.flush.assert_called_once()
        added_obj = mock_session.add.call_args[0][0]
        assert added_obj.status == "active"
        assert added_obj.user_id == FAKE_USER_ID


class TestCreatePhases:
    @pytest.mark.asyncio
    async def test_creates_phases(self, repo, mock_session):
        phases = await repo.create_phases(
            "roadmap-id",
            [{"phase_number": 1, "title": "Phase 1", "position": 0}],
        )
        mock_session.add_all.assert_called_once()
        mock_session.flush.assert_called_once()
        assert len(phases) == 1


class TestGetActiveRoadmap:
    @pytest.mark.asyncio
    async def test_returns_roadmap_when_found(self, repo, mock_session):
        fake_roadmap = MagicMock()
        result_mock = MagicMock()
        result_mock.scalar_one_or_none.return_value = fake_roadmap
        mock_session.execute.return_value = result_mock

        result = await repo.get_active_roadmap(FAKE_USER_ID)
        assert result == fake_roadmap

    @pytest.mark.asyncio
    async def test_returns_none_when_not_found(self, repo, mock_session):
        result_mock = MagicMock()
        result_mock.scalar_one_or_none.return_value = None
        mock_session.execute.return_value = result_mock

        result = await repo.get_active_roadmap(FAKE_USER_ID)
        assert result is None


class TestArchiveActive:
    @pytest.mark.asyncio
    async def test_executes_update_and_flushes(self, repo, mock_session):
        await repo.archive_active(FAKE_USER_ID)
        mock_session.execute.assert_called_once()
        mock_session.flush.assert_called_once()


class TestSetGenerationStatus:
    @pytest.mark.asyncio
    async def test_executes_update_and_flushes(self, repo, mock_session):
        await repo.set_generation_status(FAKE_USER_ID, "ready")
        mock_session.execute.assert_called_once()
        mock_session.flush.assert_called_once()
