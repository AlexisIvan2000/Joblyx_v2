# Tests pour services/interview/interview_prompt_builder.py.

from services.interview.interview_prompt_builder import (
    build_interview_prompt,
    build_summary_prompt,
)


class TestBuildInterviewPrompt:
    def test_returns_string(self):
        result = build_interview_prompt("Dev")
        assert isinstance(result, str)

    def test_contains_job_title(self):
        result = build_interview_prompt("Backend Developer")
        assert "Backend Developer" in result

    def test_contains_company_when_provided(self):
        result = build_interview_prompt("Dev", company_name="Google")
        assert "Google" in result

    def test_no_company_clause_when_none(self):
        result = build_interview_prompt("Dev")
        assert " chez " not in result

    def test_contains_job_description_when_provided(self):
        result = build_interview_prompt("Dev", job_description="Build APIs")
        assert "Build APIs" in result

    def test_french_by_default(self):
        result = build_interview_prompt("Dev")
        assert "français" in result.lower()

    def test_english_language(self):
        result = build_interview_prompt("Dev", language="en")
        assert "English" in result

    def test_contains_feedback_delimiter(self):
        result = build_interview_prompt("Dev")
        assert "<<<FEEDBACK_JSON>>>" in result

    def test_contains_star_method(self):
        result = build_interview_prompt("Dev")
        assert "STAR" in result

    def test_contains_15_questions(self):
        result = build_interview_prompt("Dev")
        assert "15" in result

    def test_contains_security_rules(self):
        result = build_interview_prompt("Dev")
        assert "prompt injection" in result.lower() or "SÉCURITÉ" in result


class TestBuildSummaryPrompt:
    def test_returns_string(self):
        result = build_summary_prompt()
        assert isinstance(result, str)

    def test_contains_json_structure(self):
        result = build_summary_prompt()
        assert "overall_score" in result
        assert "category_scores" in result
        assert "candidate_questions" in result

    def test_french_by_default(self):
        result = build_summary_prompt()
        assert "français" in result.lower()

    def test_english(self):
        result = build_summary_prompt("en")
        assert "English" in result
