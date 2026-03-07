"""Tests pour repositories/roadmap_repository.py."""

import uuid
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from repositories.roadmap_repository import RoadmapRepository
from tests.conftest import FAKE_USER_ID


@pytest.fixture
def mock_session():
    session = AsyncMock()
    session.flush = AsyncMock()
    return session


@pytest.fixture
def repo(mock_session):
    return RoadmapRepository(mock_session)


class TestCreate:
    @pytest.mark.asyncio
    async def test_creates_roadmap_with_active_status(self, repo, mock_session):
        roadmap = await repo.create(
            user_id=FAKE_USER_ID,
            target_jobs=["Developer"],
            market_data=None,
            phases=[{"title": "Phase 1"}],
        )
        mock_session.add.assert_called_once()
        mock_session.flush.assert_called_once()
        added_obj = mock_session.add.call_args[0][0]
        assert added_obj.status == "active"
        assert added_obj.user_id == FAKE_USER_ID
        assert added_obj.target_jobs == ["Developer"]
        assert added_obj.phases == [{"title": "Phase 1"}]


class TestGetActiveByUserId:
    @pytest.mark.asyncio
    async def test_returns_roadmap_when_found(self, repo, mock_session):
        fake_roadmap = MagicMock()
        result_mock = MagicMock()
        result_mock.scalar_one_or_none.return_value = fake_roadmap
        mock_session.execute.return_value = result_mock

        result = await repo.get_active_by_user_id(FAKE_USER_ID)
        assert result == fake_roadmap

    @pytest.mark.asyncio
    async def test_returns_none_when_not_found(self, repo, mock_session):
        result_mock = MagicMock()
        result_mock.scalar_one_or_none.return_value = None
        mock_session.execute.return_value = result_mock

        result = await repo.get_active_by_user_id(FAKE_USER_ID)
        assert result is None


class TestArchiveActive:
    @pytest.mark.asyncio
    async def test_executes_update_and_flushes(self, repo, mock_session):
        await repo.archive_active(FAKE_USER_ID)
        mock_session.execute.assert_called_once()
        mock_session.flush.assert_called_once()


class TestGetHistoryByUserId:
    @pytest.mark.asyncio
    async def test_returns_list_of_archived(self, repo, mock_session):
        r1, r2 = MagicMock(), MagicMock()
        scalars_mock = MagicMock()
        scalars_mock.all.return_value = [r1, r2]
        result_mock = MagicMock()
        result_mock.scalars.return_value = scalars_mock
        mock_session.execute.return_value = result_mock

        result = await repo.get_history_by_user_id(FAKE_USER_ID)
        assert result == [r1, r2]


class TestSetGenerationStatus:
    @pytest.mark.asyncio
    async def test_executes_update_and_flushes(self, repo, mock_session):
        await repo.set_generation_status(FAKE_USER_ID, "ready")
        mock_session.execute.assert_called_once()
        mock_session.flush.assert_called_once()
