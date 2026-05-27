import pytest
from unittest.mock import patch, MagicMock, AsyncMock
from services.analysis.jsearch_service import JSearchService


@pytest.fixture
def jsearch_service():
    return JSearchService()


class TestSearchJobs:
    """Tests pour la méthode search_jobs."""

    @pytest.mark.asyncio
    async def test_returns_results(self, jsearch_service):
        """Vérifie que search_jobs retourne les résultats de l'API."""
        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_response.json.return_value = {
            "data": [
                {"job_title": "Dev Python", "employer_name": "Google"},
                {"job_title": "Backend Engineer", "employer_name": "Meta"},
            ]
        }
        mock_response.raise_for_status = MagicMock()

        with patch("services.analysis.jsearch_service.httpx.AsyncClient") as MockClient:
            mock_client = AsyncMock()
            mock_client.get = AsyncMock(return_value=mock_response)
            mock_client.__aenter__ = AsyncMock(return_value=mock_client)
            mock_client.__aexit__ = AsyncMock(return_value=False)
            MockClient.return_value = mock_client

            result = await jsearch_service.search_jobs("python developer")

        assert len(result) == 2
        assert result[0]["job_title"] == "Dev Python"

    @pytest.mark.asyncio
    async def test_builds_query_with_location(self, jsearch_service):
        """Vérifie que la location est ajoutée à la query."""
        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_response.json.return_value = {"data": []}
        mock_response.raise_for_status = MagicMock()

        with patch("services.analysis.jsearch_service.httpx.AsyncClient") as MockClient:
            mock_client = AsyncMock()
            mock_client.get = AsyncMock(return_value=mock_response)
            mock_client.__aenter__ = AsyncMock(return_value=mock_client)
            mock_client.__aexit__ = AsyncMock(return_value=False)
            MockClient.return_value = mock_client

            await jsearch_service.search_jobs("python developer", location="Montreal")

            # Vérifie que le paramètre query contient la location
            call_kwargs = mock_client.get.call_args
            params = call_kwargs.kwargs.get("params") or call_kwargs[1].get("params")
            assert "Montreal" in params["query"]

    @pytest.mark.asyncio
    async def test_returns_empty_on_http_error(self, jsearch_service):
        """Vérifie que search_jobs retourne une liste vide en cas d'erreur HTTP."""
        import httpx

        mock_response = MagicMock()
        mock_response.status_code = 429
        mock_response.text = "Too Many Requests"

        with patch("services.analysis.jsearch_service.httpx.AsyncClient") as MockClient:
            mock_client = AsyncMock()
            mock_client.get = AsyncMock(
                side_effect=httpx.HTTPStatusError(
                    "429", request=MagicMock(), response=mock_response
                )
            )
            mock_client.__aenter__ = AsyncMock(return_value=mock_client)
            mock_client.__aexit__ = AsyncMock(return_value=False)
            MockClient.return_value = mock_client

            result = await jsearch_service.search_jobs("python developer")

        assert result == []

    @pytest.mark.asyncio
    async def test_returns_empty_on_request_error(self, jsearch_service):
        """Vérifie que search_jobs retourne une liste vide en cas d'erreur réseau."""
        import httpx

        with patch("services.analysis.jsearch_service.httpx.AsyncClient") as MockClient:
            mock_client = AsyncMock()
            mock_client.get = AsyncMock(
                side_effect=httpx.RequestError("Connection refused", request=MagicMock())
            )
            mock_client.__aenter__ = AsyncMock(return_value=mock_client)
            mock_client.__aexit__ = AsyncMock(return_value=False)
            MockClient.return_value = mock_client

            result = await jsearch_service.search_jobs("python developer")

        assert result == []

    @pytest.mark.asyncio
    async def test_returns_empty_when_no_data_key(self, jsearch_service):
        """Vérifie le comportement quand la réponse ne contient pas la clé 'data'."""
        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_response.json.return_value = {"status": "OK"}
        mock_response.raise_for_status = MagicMock()

        with patch("services.analysis.jsearch_service.httpx.AsyncClient") as MockClient:
            mock_client = AsyncMock()
            mock_client.get = AsyncMock(return_value=mock_response)
            mock_client.__aenter__ = AsyncMock(return_value=mock_client)
            mock_client.__aexit__ = AsyncMock(return_value=False)
            MockClient.return_value = mock_client

            result = await jsearch_service.search_jobs("python developer")

        assert result == []


class TestGetJobDescriptions:
    """Tests pour la méthode get_job_descriptions."""

    @pytest.mark.asyncio
    async def test_extracts_descriptions(self, jsearch_service):
        """Vérifie l'extraction des descriptions depuis les résultats."""
        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_response.json.return_value = {
            "data": [
                {"job_description": "Build APIs with Python"},
                {"job_description": "Design distributed systems"},
                {"other_field": "no description here"},
            ]
        }
        mock_response.raise_for_status = MagicMock()

        with patch("services.analysis.jsearch_service.httpx.AsyncClient") as MockClient:
            mock_client = AsyncMock()
            mock_client.get = AsyncMock(return_value=mock_response)
            mock_client.__aenter__ = AsyncMock(return_value=mock_client)
            mock_client.__aexit__ = AsyncMock(return_value=False)
            MockClient.return_value = mock_client

            descriptions = await jsearch_service.get_job_descriptions("python developer")

        assert len(descriptions) == 2
        assert "Build APIs with Python" in descriptions
        assert "Design distributed systems" in descriptions

    @pytest.mark.asyncio
    async def test_returns_empty_for_no_results(self, jsearch_service):
        """Vérifie que get_job_descriptions retourne une liste vide sans résultats."""
        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_response.json.return_value = {"data": []}
        mock_response.raise_for_status = MagicMock()

        with patch("services.analysis.jsearch_service.httpx.AsyncClient") as MockClient:
            mock_client = AsyncMock()
            mock_client.get = AsyncMock(return_value=mock_response)
            mock_client.__aenter__ = AsyncMock(return_value=mock_client)
            mock_client.__aexit__ = AsyncMock(return_value=False)
            MockClient.return_value = mock_client

            descriptions = await jsearch_service.get_job_descriptions("python developer")

        assert descriptions == []

    @pytest.mark.asyncio
    async def test_skips_empty_descriptions(self, jsearch_service):
        """Vérifie que les descriptions vides sont ignorées."""
        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_response.json.return_value = {
            "data": [
                {"job_description": "Valid description"},
                {"job_description": ""},
                {"job_description": "Another valid one"},
            ]
        }
        mock_response.raise_for_status = MagicMock()

        with patch("services.analysis.jsearch_service.httpx.AsyncClient") as MockClient:
            mock_client = AsyncMock()
            mock_client.get = AsyncMock(return_value=mock_response)
            mock_client.__aenter__ = AsyncMock(return_value=mock_client)
            mock_client.__aexit__ = AsyncMock(return_value=False)
            MockClient.return_value = mock_client

            descriptions = await jsearch_service.get_job_descriptions("python developer")

        assert len(descriptions) == 2
        assert "Valid description" in descriptions
