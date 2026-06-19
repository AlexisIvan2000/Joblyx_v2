

import json
import pytest
from unittest.mock import patch, MagicMock, AsyncMock




class TestGenerateRoadmap:
  

    @pytest.mark.asyncio
    async def test_returns_parsed_json(self):
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
        with patch("services.ai.openai_client.client") as mock_client:
            mock_client.chat.completions.create = AsyncMock(
                side_effect=Exception("OpenAI API error")
            )

            from services.ai.openai_client import generate_roadmap

            with pytest.raises(Exception, match="OpenAI API error"):
                await generate_roadmap("system", "user")

    @pytest.mark.asyncio
    async def test_handles_invalid_json_response(self):
        mock_response = MagicMock()
        mock_response.choices = [MagicMock()]
        mock_response.choices[0].message.content = "ceci n'est pas du JSON"

        with patch("services.ai.openai_client.client") as mock_client:
            mock_client.chat.completions.create = AsyncMock(return_value=mock_response)

            from services.ai.openai_client import generate_roadmap

            with pytest.raises(json.JSONDecodeError):
                await generate_roadmap("system", "user")


class TestGenerateRoadmapStream:

    @pytest.mark.asyncio
    async def test_yields_chunks_then_done(self):
        chunks = []
        json_parts = ['{"pha', 'ses": ', '[]}']
        for part in json_parts:
            chunk = MagicMock()
            chunk.choices = [MagicMock()]
            chunk.choices[0].delta = MagicMock()
            chunk.choices[0].delta.content = part
            chunks.append(chunk)

       
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
        assert len(chunk_events) == 3
        assert chunk_events[0][1] == '{"pha'
        assert chunk_events[1][1] == 'ses": '
        assert chunk_events[2][1] == '[]}'

        
        done_events = [e for e in events if e[0] == "done"]
        assert len(done_events) == 1
        assert done_events[0][1] == {"phases": []}

    @pytest.mark.asyncio
    async def test_yields_error_on_invalid_json(self):
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
        chunks = []
        
        c1 = MagicMock()
        c1.choices = [MagicMock()]
        c1.choices[0].delta = MagicMock()
        c1.choices[0].delta.content = '{"ok"'
        chunks.append(c1)

        
        c2 = MagicMock()
        c2.choices = [MagicMock()]
        c2.choices[0].delta = MagicMock()
        c2.choices[0].delta.content = None
        chunks.append(c2)

      
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
        assert len(chunk_events) == 2
