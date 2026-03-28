import pytest
from unittest.mock import patch, MagicMock, AsyncMock


@pytest.fixture
def r2_service():
    """Crée un R2Service avec le client S3 module-level mocké."""
    with patch("services.storage.r2_service.boto3") as mock_boto3:
        mock_client = MagicMock()
        mock_boto3.client.return_value = mock_client

        # Importer après le patch pour que _s3 utilise le mock
        import importlib
        import services.storage.r2_service as mod
        importlib.reload(mod)

        svc = mod.R2Service()
        yield svc, mock_client


class TestUploadCv:
    @pytest.mark.asyncio
    async def test_returns_key_with_correct_format(self, r2_service):
        """Vérifie que upload_cv retourne une clé au format user_id/uuid.ext."""
        svc, mock_client = r2_service
        with patch("asyncio.get_event_loop") as mock_loop:
            mock_loop.return_value.run_in_executor = AsyncMock(return_value=None)
            result = await svc.upload_cv("user123", b"pdf-content", "mon_cv.pdf")

        assert result.startswith("user123/")
        assert result.endswith(".pdf")

    @pytest.mark.asyncio
    async def test_uses_default_ext_when_no_dot(self, r2_service):
        """Vérifie que l'extension par défaut est pdf si le filename n'a pas de point."""
        svc, mock_client = r2_service
        with patch("asyncio.get_event_loop") as mock_loop:
            mock_loop.return_value.run_in_executor = AsyncMock(return_value=None)
            result = await svc.upload_cv("user123", b"content", "fichier_sans_ext")

        assert result.endswith(".pdf")


class TestGetCvUrl:
    @pytest.mark.asyncio
    async def test_returns_presigned_url(self, r2_service):
        """Vérifie que get_cv_url retourne l'URL signée générée par S3."""
        svc, mock_client = r2_service
        expected_url = "https://r2.example.com/presigned-cv-url"
        with patch("asyncio.get_event_loop") as mock_loop:
            mock_loop.return_value.run_in_executor = AsyncMock(return_value=expected_url)
            result = await svc.get_cv_url("user123/abc.pdf")

        assert result == expected_url


class TestDeleteCv:
    @pytest.mark.asyncio
    async def test_calls_delete_object(self, r2_service):
        """Vérifie que delete_cv appelle bien run_in_executor pour la suppression."""
        svc, mock_client = r2_service
        with patch("asyncio.get_event_loop") as mock_loop:
            mock_loop.return_value.run_in_executor = AsyncMock(return_value=None)
            await svc.delete_cv("user123/abc.pdf")

        mock_loop.return_value.run_in_executor.assert_called_once()


class TestUploadAvatar:
    @pytest.mark.asyncio
    async def test_returns_key_with_avatars_prefix(self, r2_service):
        """Vérifie que upload_avatar retourne une clé avec le préfixe avatars/."""
        svc, mock_client = r2_service
        with patch("asyncio.get_event_loop") as mock_loop:
            mock_loop.return_value.run_in_executor = AsyncMock(return_value=None)
            result = await svc.upload_avatar("user123", b"img-data", "image/png")

        assert result.startswith("avatars/")
        assert result == "avatars/user123.png"

    @pytest.mark.asyncio
    async def test_extracts_extension_from_content_type(self, r2_service):
        """Vérifie que l'extension est extraite du content_type."""
        svc, mock_client = r2_service
        with patch("asyncio.get_event_loop") as mock_loop:
            mock_loop.return_value.run_in_executor = AsyncMock(return_value=None)
            result = await svc.upload_avatar("user456", b"img-data", "image/jpeg")

        assert result == "avatars/user456.jpeg"


class TestGetAvatarUrl:
    @pytest.mark.asyncio
    async def test_returns_presigned_url(self, r2_service):
        """Vérifie que get_avatar_url retourne l'URL signée générée par S3."""
        svc, mock_client = r2_service
        expected_url = "https://r2.example.com/presigned-avatar-url"
        with patch("asyncio.get_event_loop") as mock_loop:
            mock_loop.return_value.run_in_executor = AsyncMock(return_value=expected_url)
            result = await svc.get_avatar_url("avatars/user123.png")

        assert result == expected_url


class TestDeleteAvatar:
    @pytest.mark.asyncio
    async def test_calls_delete_object(self, r2_service):
        """Vérifie que delete_avatar appelle bien run_in_executor pour la suppression."""
        svc, mock_client = r2_service
        with patch("asyncio.get_event_loop") as mock_loop:
            mock_loop.return_value.run_in_executor = AsyncMock(return_value=None)
            await svc.delete_avatar("avatars/user123.png")

        mock_loop.return_value.run_in_executor.assert_called_once()
