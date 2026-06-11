

import json
import pytest
from unittest.mock import patch, MagicMock, AsyncMock


# TestGenerateRoadmap

class TestGenerateRoadmap:
    """Tests pour generate_roadmap (version non-streaming)."""

    @pytest.mark.asyncio
    async def test_returns_parsed_json(self):
        """Vérifie que la réponse GPT est parsée en dict."""
        mock_response = MagicMock()
        mock_response.choices = [MagicMock()]
        mock_response.choices[0].message.content = json.dumps({
            "phases": [
                {"title": "Phase 1", "duration": "2 weeks", "tasks": []}
            ]
        })

        with patch("services.ai.openai_client.client") as mock_client:
            mock_client.chat.completions.create = AsyncMock(return_value=mock_response)

            from services.ai.openai_client import generate_roadmap
            result = await generate_roadmap("Tu es un coach carrière.", "Je veux devenir dev Python")

        assert isinstance(result, dict)
        assert "phases" in result
        assert len(result["phases"]) == 1
        assert result["phases"][0]["title"] == "Phase 1"

    @pytest.mark.asyncio
    async def test_passes_correct_messages(self):
        """Vérifie que les prompts sont envoyés correctement à l'API."""
        mock_response = MagicMock()
        mock_response.choices = [MagicMock()]
        mock_response.choices[0].message.content = '{"result": "ok"}'

        with patch("services.ai.openai_client.client") as mock_client:
            mock_client.chat.completions.create = AsyncMock(return_value=mock_response)

            from services.ai.openai_client import generate_roadmap
            await generate_roadmap("system prompt", "user prompt")

            call_kwargs = mock_client.chat.completions.create.call_args
            messages = call_kwargs.kwargs.get("messages") or call_kwargs[1].get("messages")
            assert messages[0]["role"] == "system"
            assert messages[0]["content"] == "system prompt"
            assert messages[1]["role"] == "user"
            assert messages[1]["content"] == "user prompt"

    @pytest.mark.asyncio
    async def test_handles_api_error(self):
        """Vérifie que les erreurs API remontent proprement."""
        with patch("services.ai.openai_client.client") as mock_client:
            mock_client.chat.completions.create = AsyncMock(
                side_effect=Exception("OpenAI API error")
            )

            from services.ai.openai_client import generate_roadmap

            with pytest.raises(Exception, match="OpenAI API error"):
                await generate_roadmap("system", "user")

    @pytest.mark.asyncio
    async def test_handles_invalid_json_response(self):
        """Vérifie le comportement quand GPT retourne du JSON invalide."""
        mock_response = MagicMock()
        mock_response.choices = [MagicMock()]
        mock_response.choices[0].message.content = "ceci n'est pas du JSON"

        with patch("services.ai.openai_client.client") as mock_client:
            mock_client.chat.completions.create = AsyncMock(return_value=mock_response)

            from services.ai.openai_client import generate_roadmap

            with pytest.raises(json.JSONDecodeError):
                await generate_roadmap("system", "user")


#  TestGenerateRoadmapStream 

class TestGenerateRoadmapStream:
    """Tests pour generate_roadmap_stream (version streaming SSE)."""

    @pytest.mark.asyncio
    async def test_yields_chunks_then_done(self):
        """Vérifie que le stream yield des chunks puis un événement 'done'."""
        # Simuler des chunks de streaming
        chunks = []
        json_parts = ['{"pha', 'ses": ', '[]}']
        for part in json_parts:
            chunk = MagicMock()
            chunk.choices = [MagicMock()]
            chunk.choices[0].delta = MagicMock()
            chunk.choices[0].delta.content = part
            chunks.append(chunk)

        # Créer un async iterator pour simuler le stream
        async def mock_stream():
            for c in chunks:
                yield c

        with patch("services.ai.openai_client.client") as mock_client:
            mock_client.chat.completions.create = AsyncMock(return_value=mock_stream())

            from services.ai.openai_client import generate_roadmap_stream

            events = []
            async for event in generate_roadmap_stream("system", "user"):
                events.append(event)

        # Vérifier les chunks textuels
        chunk_events = [e for e in events if e[0] == "chunk"]
        assert len(chunk_events) == 3
        assert chunk_events[0][1] == '{"pha'
        assert chunk_events[1][1] == 'ses": '
        assert chunk_events[2][1] == '[]}'

        # Vérifier l'événement 'done' avec le JSON parsé
        done_events = [e for e in events if e[0] == "done"]
        assert len(done_events) == 1
        assert done_events[0][1] == {"phases": []}

    @pytest.mark.asyncio
    async def test_yields_error_on_invalid_json(self):
        """Vérifie qu'un événement 'error' est émis si le JSON accumulé est invalide."""
        chunk = MagicMock()
        chunk.choices = [MagicMock()]
        chunk.choices[0].delta = MagicMock()
        chunk.choices[0].delta.content = "not json {"

        async def mock_stream():
            yield chunk

        with patch("services.ai.openai_client.client") as mock_client:
            mock_client.chat.completions.create = AsyncMock(return_value=mock_stream())

            from services.ai.openai_client import generate_roadmap_stream

            events = []
            async for event in generate_roadmap_stream("system", "user"):
                events.append(event)

        error_events = [e for e in events if e[0] == "error"]
        assert len(error_events) == 1
        assert "Invalid JSON" in error_events[0][1]

    @pytest.mark.asyncio
    async def test_handles_api_error(self):
        """Vérifie que les erreurs API remontent lors de la création du stream."""
        with patch("services.ai.openai_client.client") as mock_client:
            mock_client.chat.completions.create = AsyncMock(
                side_effect=Exception("Stream API error")
            )

            from services.ai.openai_client import generate_roadmap_stream

            with pytest.raises(Exception, match="Stream API error"):
                async for _ in generate_roadmap_stream("system", "user"):
                    pass

    @pytest.mark.asyncio
    async def test_skips_empty_delta_content(self):
        """Vérifie que les deltas sans contenu ne génèrent pas de chunk."""
        chunks = []
        # Un chunk avec contenu
        c1 = MagicMock()
        c1.choices = [MagicMock()]
        c1.choices[0].delta = MagicMock()
        c1.choices[0].delta.content = '{"ok"'
        chunks.append(c1)

        # Un chunk sans contenu (None)
        c2 = MagicMock()
        c2.choices = [MagicMock()]
        c2.choices[0].delta = MagicMock()
        c2.choices[0].delta.content = None
        chunks.append(c2)

        # Un chunk avec contenu
        c3 = MagicMock()
        c3.choices = [MagicMock()]
        c3.choices[0].delta = MagicMock()
        c3.choices[0].delta.content = ': true}'
        chunks.append(c3)

        async def mock_stream():
            for c in chunks:
                yield c

        with patch("services.ai.openai_client.client") as mock_client:
            mock_client.chat.completions.create = AsyncMock(return_value=mock_stream())

            from services.ai.openai_client import generate_roadmap_stream

            events = []
            async for event in generate_roadmap_stream("system", "user"):
                events.append(event)

        chunk_events = [e for e in events if e[0] == "chunk"]
        # Seulement 2 chunks (le None est ignoré)
        assert len(chunk_events) == 2
