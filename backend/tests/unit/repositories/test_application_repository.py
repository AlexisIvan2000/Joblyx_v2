import uuid
import pytest

from datetime import datetime, timezone
from unittest.mock import AsyncMock, MagicMock
from repositories.application_repository import ApplicationRepository
from models.db_models import Application
from tests.conftest import FAKE_USER_ID


FAKE_APP_ID = "22222222-2222-2222-2222-222222222222"


def _mock_app(**overrides):
    defaults = {
        "id": uuid.UUID(FAKE_APP_ID),
        "user_id": uuid.UUID(FAKE_USER_ID),
        "company_name": "Acme Corp",
        "job_title": "Backend Developer",
        "job_url": "https://acme.com/jobs/1",
        "job_description": "Build APIs",
        "status": "applied",
        "cv_file_key": None,
        "notes": None,
        "applied_at": datetime.now(timezone.utc),
        "updated_at": datetime.now(timezone.utc),
    }
    defaults.update(overrides)
    return MagicMock(**defaults)


@pytest.fixture
def mock_session():
    session = AsyncMock()
    session.add = MagicMock()
    session.add_all = MagicMock()
    session.flush = AsyncMock()
    return session


@pytest.fixture
def repo(mock_session):
    return ApplicationRepository(mock_session)


class TestCreate:
    @pytest.mark.asyncio
    async def test_creates_application(self, repo, mock_session):
        data = {"company_name": "Acme", "job_title": "Dev", "status": "applied"}
        await repo.create(FAKE_USER_ID, data)

        mock_session.add.assert_called_once()
        mock_session.flush.assert_called_once()

    @pytest.mark.asyncio
    async def test_passes_cv_file_key(self, repo, mock_session):
        data = {"company_name": "Acme", "job_title": "Dev", "status": "applied", "cv_file_key": "user/abc.pdf"}
        await repo.create(FAKE_USER_ID, data)

        added_obj = mock_session.add.call_args[0][0]
        assert added_obj.cv_file_key == "user/abc.pdf"


class TestGetById:
    @pytest.mark.asyncio
    async def test_returns_app_when_found(self, repo, mock_session):
        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = _mock_app()
        mock_session.execute.return_value = mock_result

        result = await repo.get_by_id(FAKE_APP_ID, FAKE_USER_ID)
        assert result is not None
        assert result.company_name == "Acme Corp"

    @pytest.mark.asyncio
    async def test_returns_none_when_not_found(self, repo, mock_session):
        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = None
        mock_session.execute.return_value = mock_result

        result = await repo.get_by_id(FAKE_APP_ID, FAKE_USER_ID)
        assert result is None


class TestGetAllByUser:
    @pytest.mark.asyncio
    async def test_returns_list(self, repo, mock_session):
        mock_scalars = MagicMock()
        mock_scalars.all.return_value = [_mock_app(), _mock_app(company_name="Other")]
        mock_result = MagicMock()
        mock_result.scalars.return_value = mock_scalars
        mock_session.execute.return_value = mock_result

        result = await repo.get_all_by_user(FAKE_USER_ID)
        assert len(result) == 2

    @pytest.mark.asyncio
    async def test_filters_by_status(self, repo, mock_session):
        mock_scalars = MagicMock()
        mock_scalars.all.return_value = [_mock_app(status="rejected")]
        mock_result = MagicMock()
        mock_result.scalars.return_value = mock_scalars
        mock_session.execute.return_value = mock_result

        result = await repo.get_all_by_user(FAKE_USER_ID, status_filter="rejected")
        assert len(result) == 1
        mock_session.execute.assert_called_once()


class TestUpdate:
    @pytest.mark.asyncio
    async def test_returns_updated_app(self, repo, mock_session):
        app = _mock_app()
        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = app
        mock_session.execute.return_value = mock_result

        result = await repo.update(FAKE_APP_ID, FAKE_USER_ID, {"status": "offer"})
        assert result is not None

    @pytest.mark.asyncio
    async def test_returns_none_when_not_found(self, repo, mock_session):
        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = None
        mock_session.execute.return_value = mock_result

        result = await repo.update(FAKE_APP_ID, FAKE_USER_ID, {"status": "offer"})
        assert result is None


class TestDelete:
    @pytest.mark.asyncio
    async def test_returns_deleted_app(self, repo, mock_session):
        app = _mock_app()
        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = app
        mock_session.execute.return_value = mock_result

        result = await repo.delete(FAKE_APP_ID, FAKE_USER_ID)
        assert result is not None

    @pytest.mark.asyncio
    async def test_returns_none_when_not_found(self, repo, mock_session):
        mock_result = MagicMock()
        mock_result.scalar_one_or_none.return_value = None
        mock_session.execute.return_value = mock_result

        result = await repo.delete(FAKE_APP_ID, FAKE_USER_ID)
        assert result is None
