"""Tests pour services/applications/application_service.py."""

from unittest.mock import AsyncMock, MagicMock

import pytest
from fastapi import HTTPException

from services.applications.application_service import ApplicationService
from tests.conftest import FAKE_USER_ID


FAKE_APP_ID = "22222222-2222-2222-2222-222222222222"


def _mock_app(**overrides):
    defaults = {
        "id": FAKE_APP_ID,
        "user_id": FAKE_USER_ID,
        "company_name": "Acme Corp",
        "job_title": "Backend Developer",
        "status": "applied",
        "cv_file_key": None,
        "notes": None,
    }
    defaults.update(overrides)
    return MagicMock(**defaults)


@pytest.fixture
def mock_repo():
    repo = AsyncMock()
    repo.create.return_value = _mock_app()
    repo.get_by_id.return_value = _mock_app()
    repo.get_all_by_user.return_value = [_mock_app()]
    repo.update.return_value = _mock_app()
    repo.delete.return_value = _mock_app()
    return repo


@pytest.fixture
def mock_r2():
    r2 = AsyncMock()
    r2.upload_cv.return_value = "user/abc.pdf"
    r2.get_cv_url.return_value = "https://signed-url.com/cv.pdf"
    r2.delete_cv.return_value = None
    return r2


@pytest.fixture
def service(mock_repo, mock_r2):
    return ApplicationService(mock_repo, mock_r2)


class TestCreate:
    @pytest.mark.asyncio
    async def test_creates_without_cv(self, service, mock_repo, mock_r2):
        data = {"company_name": "Acme", "job_title": "Dev", "status": "applied"}
        result = await service.create(FAKE_USER_ID, data)

        mock_repo.create.assert_called_once_with(FAKE_USER_ID, data)
        mock_r2.upload_cv.assert_not_called()
        assert result.company_name == "Acme Corp"

    @pytest.mark.asyncio
    async def test_creates_with_cv(self, service, mock_repo, mock_r2):
        data = {"company_name": "Acme", "job_title": "Dev", "status": "applied"}
        await service.create(FAKE_USER_ID, data, cv_bytes=b"pdf-content", cv_filename="cv.pdf")

        mock_r2.upload_cv.assert_called_once_with(FAKE_USER_ID, b"pdf-content", "cv.pdf")
        # Le file_key doit être ajouté à data
        assert data["cv_file_key"] == "user/abc.pdf"
        mock_repo.create.assert_called_once()


class TestGetById:
    @pytest.mark.asyncio
    async def test_returns_app(self, service, mock_repo):
        result = await service.get_by_id(FAKE_APP_ID, FAKE_USER_ID)
        assert result.company_name == "Acme Corp"

    @pytest.mark.asyncio
    async def test_raises_404_when_not_found(self, service, mock_repo):
        mock_repo.get_by_id.return_value = None
        with pytest.raises(HTTPException) as exc:
            await service.get_by_id(FAKE_APP_ID, FAKE_USER_ID)
        assert exc.value.status_code == 404


class TestGetAll:
    @pytest.mark.asyncio
    async def test_returns_list(self, service, mock_repo):
        result = await service.get_all(FAKE_USER_ID)
        assert len(result) == 1

    @pytest.mark.asyncio
    async def test_passes_status_filter(self, service, mock_repo):
        await service.get_all(FAKE_USER_ID, status_filter="rejected")
        mock_repo.get_all_by_user.assert_called_once_with(FAKE_USER_ID, "rejected")


class TestUpdate:
    @pytest.mark.asyncio
    async def test_updates_app(self, service, mock_repo):
        result = await service.update(FAKE_APP_ID, FAKE_USER_ID, {"status": "offer"})
        mock_repo.update.assert_called_once_with(FAKE_APP_ID, FAKE_USER_ID, {"status": "offer"})
        assert result is not None

    @pytest.mark.asyncio
    async def test_raises_400_when_no_fields(self, service):
        with pytest.raises(HTTPException) as exc:
            await service.update(FAKE_APP_ID, FAKE_USER_ID, {"status": None, "notes": None})
        assert exc.value.status_code == 400

    @pytest.mark.asyncio
    async def test_raises_404_when_not_found(self, service, mock_repo):
        mock_repo.update.return_value = None
        with pytest.raises(HTTPException) as exc:
            await service.update(FAKE_APP_ID, FAKE_USER_ID, {"status": "offer"})
        assert exc.value.status_code == 404

    @pytest.mark.asyncio
    async def test_updates_with_new_cv(self, service, mock_repo, mock_r2):
        mock_repo.get_by_id.return_value = _mock_app(cv_file_key=None)
        await service.update(
            FAKE_APP_ID, FAKE_USER_ID, {"status": "applied"},
            cv_bytes=b"new-pdf", cv_filename="new_cv.pdf",
        )
        mock_r2.upload_cv.assert_called_once_with(FAKE_USER_ID, b"new-pdf", "new_cv.pdf")
        # Le cv_file_key est ajouté aux données
        call_data = mock_repo.update.call_args[0][2]
        assert call_data["cv_file_key"] == "user/abc.pdf"

    @pytest.mark.asyncio
    async def test_replaces_existing_cv(self, service, mock_repo, mock_r2):
        mock_repo.get_by_id.return_value = _mock_app(cv_file_key="old/cv.pdf")
        await service.update(
            FAKE_APP_ID, FAKE_USER_ID, {"status": "applied"},
            cv_bytes=b"new-pdf", cv_filename="new_cv.pdf",
        )
        # L'ancien CV doit être supprimé
        mock_r2.delete_cv.assert_called_once_with("old/cv.pdf")
        mock_r2.upload_cv.assert_called_once()

    @pytest.mark.asyncio
    async def test_update_without_cv_does_not_touch_r2(self, service, mock_repo, mock_r2):
        await service.update(FAKE_APP_ID, FAKE_USER_ID, {"status": "offer"})
        mock_r2.upload_cv.assert_not_called()
        mock_r2.delete_cv.assert_not_called()


class TestDelete:
    @pytest.mark.asyncio
    async def test_deletes_app(self, service, mock_repo, mock_r2):
        await service.delete(FAKE_APP_ID, FAKE_USER_ID)
        mock_repo.delete.assert_called_once_with(FAKE_APP_ID, FAKE_USER_ID)
        # Pas de CV à supprimer
        mock_r2.delete_cv.assert_not_called()

    @pytest.mark.asyncio
    async def test_deletes_cv_from_r2(self, service, mock_repo, mock_r2):
        mock_repo.delete.return_value = _mock_app(cv_file_key="user/abc.pdf")
        await service.delete(FAKE_APP_ID, FAKE_USER_ID)
        mock_r2.delete_cv.assert_called_once_with("user/abc.pdf")

    @pytest.mark.asyncio
    async def test_raises_404_when_not_found(self, service, mock_repo):
        mock_repo.delete.return_value = None
        with pytest.raises(HTTPException) as exc:
            await service.delete(FAKE_APP_ID, FAKE_USER_ID)
        assert exc.value.status_code == 404


class TestGetCvUrl:
    @pytest.mark.asyncio
    async def test_returns_signed_url(self, service, mock_repo, mock_r2):
        mock_repo.get_by_id.return_value = _mock_app(cv_file_key="user/abc.pdf")
        url = await service.get_cv_url(FAKE_APP_ID, FAKE_USER_ID)
        assert url == "https://signed-url.com/cv.pdf"
        mock_r2.get_cv_url.assert_called_once_with("user/abc.pdf")

    @pytest.mark.asyncio
    async def test_raises_404_when_no_cv(self, service, mock_repo):
        mock_repo.get_by_id.return_value = _mock_app(cv_file_key=None)
        with pytest.raises(HTTPException) as exc:
            await service.get_cv_url(FAKE_APP_ID, FAKE_USER_ID)
        assert exc.value.status_code == 404
