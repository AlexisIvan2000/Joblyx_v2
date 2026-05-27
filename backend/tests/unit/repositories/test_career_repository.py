# Tests for repositories/career_repository.py.

from unittest.mock import AsyncMock

import pytest

from repositories.career_repository import CareerRepository


@pytest.fixture
def mock_session():
    return AsyncMock()


@pytest.fixture
def repo(mock_session):
    return CareerRepository(mock_session)


class TestCareerRepository:
    def test_instantiates(self, repo, mock_session):
        assert repo.session is mock_session

    def test_exposes_expected_methods(self, repo):
        # Le repo doit exposer toutes les méthodes Career + UserSkill + market cache lecture
        expected_methods = {
            "get_by_user_id",
            "create",
            "update_fields",
            "upsert",
            "set_generation_status",
            "increment_regeneration_count",
            "reset_regeneration_counter",
            "get_skills",
            "delete_skills",
            "replace_skills",
            "get_market_skills",
        }
        actual = {name for name in dir(repo) if not name.startswith("_")}
        missing = expected_methods - actual
        assert not missing, f"Méthodes manquantes : {missing}"
