"""Tests pour le module services.ai.cv_parser."""

import json
import pytest
from unittest.mock import patch, MagicMock, AsyncMock


# ─── Helpers ────────────────────────────────────────────────────────────

def _mock_fitz_doc(pages_text: list[str]):
    """Construit un mock fitz.Document avec les pages données."""
    mock_doc = MagicMock()
    mock_pages = []
    for text in pages_text:
        page = MagicMock()
        page.get_text.return_value = text
        mock_pages.append(page)
    mock_doc.__iter__ = MagicMock(return_value=iter(mock_pages))
    mock_doc.close = MagicMock()
    return mock_doc


# ─── TestExtractTextFromPdf ─────────────────────────────────────────────

class TestExtractTextFromPdf:
    """Tests pour extract_text_from_pdf."""

    def test_extracts_text_from_single_page(self):
        """Vérifie l'extraction de texte d'un PDF à une seule page."""
        with patch("services.ai.cv_parser.fitz") as mock_fitz:
            mock_fitz.open.return_value = _mock_fitz_doc(["Hello World"])

            from services.ai.cv_parser import extract_text_from_pdf
            result = extract_text_from_pdf(b"fake-pdf-bytes")

            assert result == "Hello World"
            mock_fitz.open.assert_called_once_with(stream=b"fake-pdf-bytes", filetype="pdf")

    def test_extracts_text_from_multiple_pages(self):
        """Vérifie la concaténation du texte de plusieurs pages."""
        with patch("services.ai.cv_parser.fitz") as mock_fitz:
            mock_fitz.open.return_value = _mock_fitz_doc([
                "Page 1 content\n",
                "Page 2 content\n",
                "Page 3 content",
            ])

            from services.ai.cv_parser import extract_text_from_pdf
            result = extract_text_from_pdf(b"multi-page-pdf")

            assert "Page 1 content" in result
            assert "Page 2 content" in result
            assert "Page 3 content" in result

    def test_returns_stripped_text(self):
        """Vérifie que le résultat est strippé (pas d'espaces en début/fin)."""
        with patch("services.ai.cv_parser.fitz") as mock_fitz:
            mock_fitz.open.return_value = _mock_fitz_doc(["  some text  \n  "])

            from services.ai.cv_parser import extract_text_from_pdf
            result = extract_text_from_pdf(b"pdf")

            assert result == "some text"

    def test_returns_empty_for_blank_pdf(self):
        """Vérifie le retour d'une chaîne vide pour un PDF sans texte."""
        with patch("services.ai.cv_parser.fitz") as mock_fitz:
            mock_fitz.open.return_value = _mock_fitz_doc(["   ", ""])

            from services.ai.cv_parser import extract_text_from_pdf
            result = extract_text_from_pdf(b"blank")

            assert result == ""


# ─── TestValidateSkills ─────────────────────────────────────────────────

class TestValidateSkills:
    """Tests pour _validate_skills (normalisation et filtrage)."""

    def test_normalizes_known_skill(self):
        """Vérifie que les skills connues sont normalisées via l'index."""
        from services.ai.cv_parser import _validate_skills, _SKILL_INDEX

        # Prendre un skill existant dans l'index pour le test
        if not _SKILL_INDEX:
            pytest.skip("Aucun skill dans l'index de référence")

        # Récupérer un skill connu
        sample_key = next(iter(_SKILL_INDEX))
        expected_name, expected_cat = _SKILL_INDEX[sample_key]

        raw = [{"skill_name": sample_key, "category": "wrong_cat", "proficiency": "advanced"}]
        result = _validate_skills(raw)

        assert len(result) == 1
        assert result[0]["skill_name"] == expected_name
        assert result[0]["category"] == expected_cat
        assert result[0]["proficiency"] == "advanced"

    def test_filters_unknown_skills(self):
        """Vérifie que les skills inconnus sont filtrés."""
        from services.ai.cv_parser import _validate_skills

        raw = [{"skill_name": "UnknownSkillXYZ123", "category": "FakeCategory", "proficiency": "advanced"}]
        result = _validate_skills(raw)

        assert len(result) == 0

    def test_defaults_proficiency_to_intermediate(self):
        """Vérifie le proficiency par défaut à 'intermediate' pour les valeurs invalides."""
        from services.ai.cv_parser import _validate_skills, _SKILL_INDEX

        if not _SKILL_INDEX:
            pytest.skip("Aucun skill dans l'index de référence")

        sample_key = next(iter(_SKILL_INDEX))
        expected_name, expected_cat = _SKILL_INDEX[sample_key]

        raw = [{"skill_name": sample_key, "category": expected_cat, "proficiency": "expert"}]
        result = _validate_skills(raw)

        assert len(result) == 1
        assert result[0]["proficiency"] == "intermediate"

    def test_deduplicates_skills(self):
        """Vérifie qu'il n'y a pas de doublons dans les résultats."""
        from services.ai.cv_parser import _validate_skills, _SKILL_INDEX

        if not _SKILL_INDEX:
            pytest.skip("Aucun skill dans l'index de référence")

        sample_key = next(iter(_SKILL_INDEX))
        expected_name, expected_cat = _SKILL_INDEX[sample_key]

        raw = [
            {"skill_name": sample_key, "category": expected_cat, "proficiency": "advanced"},
            {"skill_name": sample_key, "category": expected_cat, "proficiency": "beginner"},
        ]
        result = _validate_skills(raw)

        assert len(result) == 1

    def test_empty_input_returns_empty(self):
        """Vérifie qu'une liste vide en entrée retourne une liste vide."""
        from services.ai.cv_parser import _validate_skills

        assert _validate_skills([]) == []


# ─── TestExtractSkillsFromCv ────────────────────────────────────────────

class TestExtractSkillsFromCv:
    """Tests pour extract_skills_from_cv (appel GPT mocké)."""

    @pytest.mark.asyncio
    async def test_extracts_skills_successfully(self):
        """Vérifie l'extraction de skills avec un retour GPT valide."""
        from services.ai.cv_parser import extract_skills_from_cv, _SKILL_INDEX

        if not _SKILL_INDEX:
            pytest.skip("Aucun skill dans l'index de référence")

        # Choisir un skill connu pour le mock GPT
        sample_key = next(iter(_SKILL_INDEX))
        expected_name, expected_cat = _SKILL_INDEX[sample_key]

        mock_response = MagicMock()
        mock_response.choices = [MagicMock()]
        mock_response.choices[0].message.content = json.dumps({
            "skills": [
                {"skill_name": expected_name, "category": expected_cat, "proficiency": "advanced"}
            ]
        })

        with patch("services.ai.cv_parser.fitz") as mock_fitz, \
             patch("services.ai.cv_parser.client") as mock_client:
            mock_fitz.open.return_value = _mock_fitz_doc(["Je maîtrise Python et Docker"])
            mock_client.chat.completions.create = AsyncMock(return_value=mock_response)

            result = await extract_skills_from_cv(b"fake-pdf")

        assert len(result) >= 1
        assert result[0]["skill_name"] == expected_name

    @pytest.mark.asyncio
    async def test_returns_empty_for_blank_cv(self):
        """Vérifie le retour d'une liste vide pour un CV sans texte."""
        from services.ai.cv_parser import extract_skills_from_cv

        with patch("services.ai.cv_parser.fitz") as mock_fitz:
            mock_fitz.open.return_value = _mock_fitz_doc([""])

            result = await extract_skills_from_cv(b"blank-pdf")

        assert result == []

    @pytest.mark.asyncio
    async def test_handles_gpt_error_gracefully(self):
        """Vérifie que les erreurs GPT remontent proprement."""
        from services.ai.cv_parser import extract_skills_from_cv

        with patch("services.ai.cv_parser.fitz") as mock_fitz, \
             patch("services.ai.cv_parser.client") as mock_client:
            mock_fitz.open.return_value = _mock_fitz_doc(["Some CV content here"])
            mock_client.chat.completions.create = AsyncMock(
                side_effect=Exception("API rate limit exceeded")
            )

            with pytest.raises(Exception, match="API rate limit exceeded"):
                await extract_skills_from_cv(b"pdf-bytes")

    @pytest.mark.asyncio
    async def test_handles_invalid_json_from_gpt(self):
        """Vérifie le comportement quand GPT retourne du JSON invalide."""
        from services.ai.cv_parser import extract_skills_from_cv

        mock_response = MagicMock()
        mock_response.choices = [MagicMock()]
        mock_response.choices[0].message.content = "not valid json {"

        with patch("services.ai.cv_parser.fitz") as mock_fitz, \
             patch("services.ai.cv_parser.client") as mock_client:
            mock_fitz.open.return_value = _mock_fitz_doc(["Un CV avec du texte"])
            mock_client.chat.completions.create = AsyncMock(return_value=mock_response)

            with pytest.raises(json.JSONDecodeError):
                await extract_skills_from_cv(b"pdf-bytes")
