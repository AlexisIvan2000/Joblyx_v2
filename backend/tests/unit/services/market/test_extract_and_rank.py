from unittest.mock import AsyncMock, patch

import pytest


@pytest.fixture
def extractor():
    """Crée un extractor avec extract_skills mocké (évite de charger spaCy)."""
    from services.analysis.spacy_skills import SpacySkillsExtractor

    ext = AsyncMock(spec=SpacySkillsExtractor)
    ext._get_category = lambda name: {
        "Python": "programming_languages",
        "Django": "backend_frameworks",
        "React": "frontend_frameworks",
        "PostgreSQL": "databases",
    }.get(name, "other")

    # Utilise la vraie implémentation de extract_and_rank
    ext.extract_and_rank = SpacySkillsExtractor.extract_and_rank.__get__(ext)
    return ext


class TestExtractAndRank:
    @pytest.mark.asyncio
    async def test_empty_descriptions(self, extractor):
        result = await extractor.extract_and_rank([])
        assert result == []

    @pytest.mark.asyncio
    async def test_ranks_by_frequency(self, extractor):
        extractor.extract_skills.side_effect = [
            ["Python", "Django", "PostgreSQL"],
            ["Python", "React", "PostgreSQL"],
            ["Python", "React"],
        ]

        result = await extractor.extract_and_rank([
            "desc1", "desc2", "desc3",
        ])

        # Python apparaît dans les 3 descriptions
        assert result[0]["name"] == "Python"
        assert result[0]["count"] == 3
        assert result[0]["percentage"] == 100

        # PostgreSQL et React dans 2 descriptions chacun
        names_at_2 = {s["name"] for s in result if s["count"] == 2}
        assert names_at_2 == {"PostgreSQL", "React"}

    @pytest.mark.asyncio
    async def test_percentage_calculation(self, extractor):
        extractor.extract_skills.side_effect = [
            ["Python"],
            ["Python"],
            ["Django"],
            ["React"],
        ]

        result = await extractor.extract_and_rank(["d1", "d2", "d3", "d4"])

        python_entry = next(s for s in result if s["name"] == "Python")
        assert python_entry["percentage"] == 50  # 2/4

    @pytest.mark.asyncio
    async def test_deduplicates_per_description(self, extractor):
        # Si un skill apparaît 2 fois dans la même description, il compte 1 seule fois
        extractor.extract_skills.side_effect = [
            ["Python", "Python", "Python"],
            ["Django"],
        ]

        result = await extractor.extract_and_rank(["d1", "d2"])

        python_entry = next(s for s in result if s["name"] == "Python")
        assert python_entry["count"] == 1  # 1 description, pas 3

    @pytest.mark.asyncio
    async def test_includes_category(self, extractor):
        extractor.extract_skills.side_effect = [
            ["Python", "React"],
        ]

        result = await extractor.extract_and_rank(["d1"])

        python_entry = next(s for s in result if s["name"] == "Python")
        assert python_entry["category"] == "programming_languages"

        react_entry = next(s for s in result if s["name"] == "React")
        assert react_entry["category"] == "frontend_frameworks"
