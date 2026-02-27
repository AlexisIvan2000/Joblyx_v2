"""Tests for repositories/career_repository.py — Supabase data access."""

from unittest.mock import MagicMock

from repositories.career_repository import CareerRepository


# ─── Helpers ──────────────────────────────────────────────────────────

def _make_repo_and_client(data=None):
    """Return (repo, mock_client, mock_chain) with chained table mock."""
    mock_client = MagicMock()

    mock_execute = MagicMock()
    mock_execute.data = data if data is not None else []

    mock_chain = MagicMock()
    mock_chain.select.return_value = mock_chain
    mock_chain.insert.return_value = mock_chain
    mock_chain.update.return_value = mock_chain
    mock_chain.eq.return_value = mock_chain
    mock_chain.execute.return_value = mock_execute

    mock_client.table.return_value = mock_chain

    return CareerRepository(mock_client), mock_client, mock_chain


# ─── get_career_profile_by_user_id ───────────────────────────────────

class TestGetCareerProfileByUserId:
    def test_found(self):
        profile = {"id": "p-1", "user_id": "u-1", "level": "junior"}
        repo, client, chain = _make_repo_and_client([profile])
        result = repo.get_career_profile_by_user_id("u-1")
        assert result == profile
        client.table.assert_called_with("career_profiles")
        chain.eq.assert_called_with("user_id", "u-1")

    def test_not_found(self):
        repo, _, _ = _make_repo_and_client([])
        assert repo.get_career_profile_by_user_id("u-1") is None


# ─── create_career_profile ───────────────────────────────────────────

class TestCreateCareerProfile:
    def test_returns_created_profile(self):
        profile = {"id": "p-1", "user_id": "u-1", "level": "junior"}
        repo, client, chain = _make_repo_and_client([profile])
        data = {"user_id": "u-1", "level": "junior"}
        result = repo.create_career_profile(data)
        assert result == profile
        client.table.assert_called_with("career_profiles")
        chain.insert.assert_called_once_with(data)


# ─── create_user_skills ──────────────────────────────────────────────

class TestCreateUserSkills:
    def test_bulk_insert(self):
        skills = [
            {"user_id": "u-1", "skill_name": "Python", "category": "Programming", "level": "advanced"},
            {"user_id": "u-1", "skill_name": "SQL", "category": "Database", "level": "intermediate"},
        ]
        repo, client, chain = _make_repo_and_client(skills)
        result = repo.create_user_skills(skills)
        assert result == skills
        client.table.assert_called_with("user_skills")
        chain.insert.assert_called_once_with(skills)


# ─── create_roadmap ──────────────────────────────────────────────────

class TestCreateRoadmap:
    def test_returns_created_roadmap(self):
        roadmap = {"id": "r-1", "user_id": "u-1", "status": "processing"}
        repo, client, chain = _make_repo_and_client([roadmap])
        data = {"user_id": "u-1", "status": "processing", "duration_days": 60}
        result = repo.create_roadmap(data)
        assert result == roadmap
        client.table.assert_called_with("roadmaps")
        chain.insert.assert_called_once_with(data)


# ─── get_roadmap_by_user_id ─────────────────────────────────────────

class TestGetRoadmapByUserId:
    def test_found(self):
        roadmap = {"id": "r-1", "user_id": "u-1", "status": "ready"}
        repo, client, chain = _make_repo_and_client([roadmap])
        result = repo.get_roadmap_by_user_id("u-1")
        assert result == roadmap
        chain.eq.assert_called_with("user_id", "u-1")

    def test_not_found(self):
        repo, _, _ = _make_repo_and_client([])
        assert repo.get_roadmap_by_user_id("u-1") is None
