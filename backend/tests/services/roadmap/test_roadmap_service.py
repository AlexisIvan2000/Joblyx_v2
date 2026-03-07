"""Tests pour services/roadmap/roadmap_service.py."""

from datetime import datetime, timedelta, timezone
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from services.roadmap.roadmap_service import RoadmapService
from tests.conftest import FAKE_USER_ID


def _mock_career(**overrides):
    defaults = {
        "level": "junior",
        "years_experience": 2,
        "target_jobs": ["Software Developer"],
        "city": "Toronto",
        "province": "ON",
        "language": "en",
        "previous_field": None,
        "generation_status": "idle",
    }
    defaults.update(overrides)
    return MagicMock(**defaults)


def _mock_cache(age_hours=1):
    return MagicMock(
        top_skills=[
            {"name": "Python", "count": 10, "percentage": 80},
            {"name": "Docker", "count": 5, "percentage": 40},
        ],
        fetched_at=datetime.now(timezone.utc) - timedelta(hours=age_hours),
    )


@pytest.fixture
def mock_session():
    session = AsyncMock()
    session.commit = AsyncMock()
    session.rollback = AsyncMock()
    return session


@pytest.fixture
def service(mock_session):
    return RoadmapService(mock_session)


class TestGenerate:
    @pytest.mark.asyncio
    async def test_success_flow(self, service, mock_session):
        # Mock _get_career
        career = _mock_career()
        with patch.object(service, '_get_career', return_value=career), \
             patch.object(service, '_get_skills', return_value=[
                 {"skill_name": "Python", "category": "programming_languages", "proficiency": "advanced"}
             ]), \
             patch.object(service, '_get_market_data', return_value=None), \
             patch("services.roadmap.roadmap_service.build_roadmap_prompt", return_value=("sys", "usr")), \
             patch("services.roadmap.roadmap_service.call_gpt", return_value={"phases": [{"title": "Phase 1"}]}):

            service.repo = AsyncMock()
            await service.generate(FAKE_USER_ID)

        # Vérifie le flow complet
        service.repo.set_generation_status.assert_any_call(FAKE_USER_ID, "generating")
        service.repo.archive_active.assert_called_once_with(FAKE_USER_ID)
        service.repo.create.assert_called_once()
        service.repo.set_generation_status.assert_any_call(FAKE_USER_ID, "ready")

    @pytest.mark.asyncio
    async def test_sets_error_on_gpt_failure(self, service, mock_session):
        career = _mock_career()
        with patch.object(service, '_get_career', return_value=career), \
             patch.object(service, '_get_skills', return_value=[]), \
             patch.object(service, '_get_market_data', return_value=None), \
             patch("services.roadmap.roadmap_service.build_roadmap_prompt", return_value=("sys", "usr")), \
             patch("services.roadmap.roadmap_service.call_gpt", side_effect=Exception("GPT error")):

            service.repo = AsyncMock()
            await service.generate(FAKE_USER_ID)

        service.repo.set_generation_status.assert_any_call(FAKE_USER_ID, "error")

    @pytest.mark.asyncio
    async def test_no_career_raises(self, service, mock_session):
        with patch.object(service, '_get_career', return_value=None):
            service.repo = AsyncMock()
            await service.generate(FAKE_USER_ID)

        # Devrait passer en erreur car career est None
        service.repo.set_generation_status.assert_any_call(FAKE_USER_ID, "error")

    @pytest.mark.asyncio
    async def test_archives_old_roadmap(self, service, mock_session):
        career = _mock_career()
        with patch.object(service, '_get_career', return_value=career), \
             patch.object(service, '_get_skills', return_value=[]), \
             patch.object(service, '_get_market_data', return_value=None), \
             patch("services.roadmap.roadmap_service.build_roadmap_prompt", return_value=("sys", "usr")), \
             patch("services.roadmap.roadmap_service.call_gpt", return_value={"phases": []}):

            service.repo = AsyncMock()
            await service.generate(FAKE_USER_ID)

        service.repo.archive_active.assert_called_once_with(FAKE_USER_ID)

    @pytest.mark.asyncio
    async def test_with_market_data(self, service, mock_session):
        career = _mock_career()
        market = [{"name": "Kubernetes", "count": 38, "percentage": 76}]
        with patch.object(service, '_get_career', return_value=career), \
             patch.object(service, '_get_skills', return_value=[]), \
             patch.object(service, '_get_market_data', return_value=market), \
             patch("services.roadmap.roadmap_service.build_roadmap_prompt", return_value=("sys", "usr")) as mock_prompt, \
             patch("services.roadmap.roadmap_service.call_gpt", return_value={"phases": []}):

            service.repo = AsyncMock()
            await service.generate(FAKE_USER_ID)

        # Vérifie que market_data est passé au prompt builder
        call_args = mock_prompt.call_args
        assert call_args[0][2] == market
