

from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from services.market.market_cache_service import MarketCacheService, CANADIAN_IT_CITIES
from tests.conftest import FAKE_USER_ID


@pytest.fixture
def mock_session():
    session = AsyncMock()
    return session


@pytest.fixture
def mock_jsearch():
    svc = AsyncMock()
    svc.get_job_descriptions.return_value = [
        "We need a Python developer with Django and PostgreSQL.",
        "Looking for a Java engineer with Spring Boot and AWS.",
    ]
    return svc


@pytest.fixture
def mock_extractor():
    ext = AsyncMock()
    ext.extract_and_rank.return_value = [
        {"name": "Python", "category": "programming_languages", "count": 2, "percentage": 100},
        {"name": "Django", "category": "backend_frameworks", "count": 1, "percentage": 50},
    ]
    return ext


@pytest.fixture
def service(mock_session, mock_jsearch, mock_extractor):
    return MarketCacheService(mock_session, mock_jsearch, mock_extractor)


#  _build_predefined_combos

class TestBuildPredefinedCombos:
    def test_returns_cartesian_product(self, service):
        combos = service._build_predefined_combos()
        # Chaque job title × chaque ville
        assert len(combos) > 0
        assert isinstance(combos, set)
        # Vérifie qu'un combo attendu existe
        assert ("Software Developer", "Toronto", "ON") in combos

    def test_all_cities_present(self, service):
        combos = service._build_predefined_combos()
        cities_in_combos = {(c, p) for _, c, p in combos}
        for city, province in CANADIAN_IT_CITIES:
            assert (city, province) in cities_in_combos


#  _get_career_combos 

class TestGetCareerCombos:
    @pytest.mark.asyncio
    async def test_extracts_combos_from_career(self, service, mock_session):
        mock_result = MagicMock()
        mock_result.all.return_value = [
            (["Blockchain Developer", "AI Engineer"], "Saskatoon", "SK"),
            (["Software Developer"], "Toronto", "ON"),
        ]
        mock_session.execute.return_value = mock_result

        combos = await service._get_career_combos()

        assert ("Blockchain Developer", "Saskatoon", "SK") in combos
        assert ("AI Engineer", "Saskatoon", "SK") in combos
        assert ("Software Developer", "Toronto", "ON") in combos
        assert len(combos) == 3

    @pytest.mark.asyncio
    async def test_skips_empty_target_jobs(self, service, mock_session):
        mock_result = MagicMock()
        mock_result.all.return_value = [
            (None, "Toronto", "ON"),
            ([], "Montreal", "QC"),
        ]
        mock_session.execute.return_value = mock_result

        combos = await service._get_career_combos()
        assert len(combos) == 0

    @pytest.mark.asyncio
    async def test_strips_whitespace(self, service, mock_session):
        mock_result = MagicMock()
        mock_result.all.return_value = [
            (["  Developer  "], "  Toronto  ", "  ON  "),
        ]
        mock_session.execute.return_value = mock_result

        combos = await service._get_career_combos()
        assert ("Developer", "Toronto", "ON") in combos


#  _upsert_cache 

class TestUpsertCache:
    @pytest.mark.asyncio
    async def test_executes_insert(self, service, mock_session):
        await service._upsert_cache(
            "Software Developer", "Toronto", "ON",
            [{"name": "Python", "count": 5, "percentage": 100}],
            job_count=10,
        )
        mock_session.execute.assert_called_once()


#  refresh_cache ─

class TestRefreshCache:
    @pytest.mark.asyncio
    async def test_processes_combos(self, service, mock_session, mock_jsearch, mock_extractor):
        # Simule _get_career_combos vide (que les prédéfinies)
        career_result = MagicMock()
        career_result.all.return_value = []
        mock_session.execute.return_value = career_result

        with patch.object(service, '_build_predefined_combos', return_value={
            ("Developer", "Toronto", "ON"),
            ("QA Engineer", "Montreal", "QC"),
        }):
            summary = await service.refresh_cache()

        assert summary["total"] == 2
        assert summary["processed"] == 2
        assert summary["skipped"] == 0
        assert mock_jsearch.get_job_descriptions.call_count == 2
        assert mock_extractor.extract_and_rank.call_count == 2
        mock_session.commit.assert_called_once()

    @pytest.mark.asyncio
    async def test_skips_when_no_descriptions(self, service, mock_session, mock_jsearch):
        career_result = MagicMock()
        career_result.all.return_value = []
        mock_session.execute.return_value = career_result

        mock_jsearch.get_job_descriptions.return_value = []

        with patch.object(service, '_build_predefined_combos', return_value={
            ("Rare Job", "Toronto", "ON"),
        }):
            summary = await service.refresh_cache()

        assert summary["processed"] == 0
        assert summary["skipped"] == 1

    @pytest.mark.asyncio
    async def test_career_extras_added(self, service, mock_session):
        career_result = MagicMock()
        career_result.all.return_value = [
            (["Blockchain Developer"], "Saskatoon", "SK"),
        ]
        mock_session.execute.return_value = career_result

        with patch.object(service, '_build_predefined_combos', return_value={
            ("Developer", "Toronto", "ON"),
        }):
            summary = await service.refresh_cache()

        # 1 prédéfinie + 1 extra depuis career
        assert summary["total"] == 2

    @pytest.mark.asyncio
    async def test_deduplication(self, service, mock_session):
        # Career retourne un combo déjà dans les prédéfinies
        career_result = MagicMock()
        career_result.all.return_value = [
            (["Developer"], "Toronto", "ON"),
        ]
        mock_session.execute.return_value = career_result

        with patch.object(service, '_build_predefined_combos', return_value={
            ("Developer", "Toronto", "ON"),
        }):
            summary = await service.refresh_cache()

        # Dédupliqué : 1 seul combo traité
        assert summary["total"] == 1

    @pytest.mark.asyncio
    async def test_continues_on_error(self, service, mock_session, mock_jsearch):
        career_result = MagicMock()
        career_result.all.return_value = []
        mock_session.execute.return_value = career_result

        # Premier combo échoue, deuxième réussit
        mock_jsearch.get_job_descriptions.side_effect = [
            Exception("API timeout"),
            ["Some job description here"],
        ]

        with patch.object(service, '_build_predefined_combos', return_value={
            ("Job A", "Toronto", "ON"),
            ("Job B", "Montreal", "QC"),
        }):
            summary = await service.refresh_cache()

        assert summary["processed"] == 1
        assert summary["skipped"] == 1
