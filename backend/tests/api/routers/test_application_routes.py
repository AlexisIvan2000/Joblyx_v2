"""Tests pour api/routers/applications.py."""

import json
from datetime import datetime, timezone
from unittest.mock import AsyncMock, MagicMock

import pytest
from fastapi import HTTPException

from tests.conftest import FAKE_USER_ID


FAKE_APP_ID = "22222222-2222-2222-2222-222222222222"


def _mock_app(**overrides):
    defaults = {
        "id": FAKE_APP_ID,
        "user_id": FAKE_USER_ID,
        "company_name": "Acme Corp",
        "job_title": "Backend Developer",
        "job_url": "https://acme.com/jobs/1",
        "job_description": "Build APIs",
        "status": "applied",
        "cv_file_key": None,
        "notes": "Great company",
        "applied_at": datetime(2026, 3, 1, tzinfo=timezone.utc),
        "updated_at": datetime(2026, 3, 1, tzinfo=timezone.utc),
    }
    defaults.update(overrides)
    return MagicMock(**defaults)


class TestCreateApplication:
    def test_creates_without_cv(self, test_client):
        svc = test_client._mock_app_svc
        svc.create.return_value = _mock_app()

        data = json.dumps({
            "company_name": "Acme Corp",
            "job_title": "Backend Developer",
        })
        resp = test_client.post("/applications", data={"data": data})

        assert resp.status_code == 200
        body = resp.json()
        assert body["company_name"] == "Acme Corp"
        assert body["job_title"] == "Backend Developer"
        assert body["status"] == "applied"
        svc.create.assert_called_once()

    def test_creates_with_cv(self, test_client):
        svc = test_client._mock_app_svc
        svc.create.return_value = _mock_app(cv_file_key="user/abc.pdf")

        data = json.dumps({
            "company_name": "Acme Corp",
            "job_title": "Backend Developer",
        })
        resp = test_client.post(
            "/applications",
            data={"data": data},
            files={"cv": ("cv.pdf", b"%PDF-fake", "application/pdf")},
        )

        assert resp.status_code == 200
        body = resp.json()
        assert body["cv_file_key"] == "user/abc.pdf"

    def test_rejects_non_pdf(self, test_client):
        data = json.dumps({
            "company_name": "Acme Corp",
            "job_title": "Backend Developer",
        })
        resp = test_client.post(
            "/applications",
            data={"data": data},
            files={"cv": ("doc.docx", b"fake", "application/msword")},
        )
        assert resp.status_code == 400

    def test_rejects_invalid_json(self, test_client):
        resp = test_client.post("/applications", data={"data": "not json"})
        assert resp.status_code == 400


class TestListApplications:
    def test_returns_empty_list(self, test_client):
        svc = test_client._mock_app_svc
        svc.get_all.return_value = []

        resp = test_client.get("/applications")
        assert resp.status_code == 200
        assert resp.json() == []

    def test_returns_list(self, test_client):
        svc = test_client._mock_app_svc
        svc.get_all.return_value = [_mock_app(), _mock_app(company_name="Other")]

        resp = test_client.get("/applications")
        assert resp.status_code == 200
        assert len(resp.json()) == 2

    def test_filters_by_status(self, test_client):
        svc = test_client._mock_app_svc
        svc.get_all.return_value = [_mock_app(status="rejected")]

        resp = test_client.get("/applications?status=rejected")
        assert resp.status_code == 200
        svc.get_all.assert_called_once_with(str(FAKE_USER_ID), status_filter="rejected")


class TestGetApplication:
    def test_returns_app(self, test_client):
        svc = test_client._mock_app_svc
        svc.get_by_id.return_value = _mock_app()

        resp = test_client.get(f"/applications/{FAKE_APP_ID}")
        assert resp.status_code == 200
        assert resp.json()["id"] == FAKE_APP_ID

    def test_returns_app_with_cv_url(self, test_client):
        svc = test_client._mock_app_svc
        svc.get_by_id.return_value = _mock_app(cv_file_key="user/abc.pdf")
        svc.get_cv_url.return_value = "https://signed.url/cv.pdf"

        resp = test_client.get(f"/applications/{FAKE_APP_ID}")
        assert resp.status_code == 200
        assert resp.json()["cv_url"] == "https://signed.url/cv.pdf"

    def test_returns_404_when_not_found(self, test_client):
        svc = test_client._mock_app_svc
        svc.get_by_id.side_effect = HTTPException(status_code=404, detail="Not found")

        resp = test_client.get(f"/applications/{FAKE_APP_ID}")
        assert resp.status_code == 404


class TestUpdateApplication:
    def test_updates_status(self, test_client):
        svc = test_client._mock_app_svc
        svc.update.return_value = _mock_app(status="offer")

        data = json.dumps({"status": "offer"})
        resp = test_client.put(
            f"/applications/{FAKE_APP_ID}",
            data={"data": data},
        )
        assert resp.status_code == 200
        assert resp.json()["status"] == "offer"

    def test_updates_with_cv(self, test_client):
        svc = test_client._mock_app_svc
        svc.update.return_value = _mock_app(status="applied", cv_file_key="user/new.pdf")
        svc.get_cv_url.return_value = "https://signed.url/new.pdf"

        data = json.dumps({"status": "applied"})
        resp = test_client.put(
            f"/applications/{FAKE_APP_ID}",
            data={"data": data},
            files={"cv": ("new_cv.pdf", b"%PDF-fake", "application/pdf")},
        )
        assert resp.status_code == 200
        svc.update.assert_called_once()
        # Vérifier que cv_bytes et cv_filename sont passés
        call_kwargs = svc.update.call_args
        assert call_kwargs.kwargs.get("cv_filename") == "new_cv.pdf"

    def test_rejects_non_pdf_cv(self, test_client):
        data = json.dumps({"status": "applied"})
        resp = test_client.put(
            f"/applications/{FAKE_APP_ID}",
            data={"data": data},
            files={"cv": ("doc.docx", b"fake", "application/msword")},
        )
        assert resp.status_code == 400

    def test_rejects_invalid_json(self, test_client):
        resp = test_client.put(
            f"/applications/{FAKE_APP_ID}",
            data={"data": "not json"},
        )
        assert resp.status_code == 400

    def test_returns_404_when_not_found(self, test_client):
        svc = test_client._mock_app_svc
        svc.update.side_effect = HTTPException(status_code=404, detail="Not found")

        data = json.dumps({"status": "offer"})
        resp = test_client.put(
            f"/applications/{FAKE_APP_ID}",
            data={"data": data},
        )
        assert resp.status_code == 404


class TestDeleteApplication:
    def test_deletes_app(self, test_client):
        svc = test_client._mock_app_svc
        svc.delete.return_value = None

        resp = test_client.delete(f"/applications/{FAKE_APP_ID}")
        assert resp.status_code == 200
        assert resp.json()["message"] == "Application deleted"

    def test_returns_404_when_not_found(self, test_client):
        svc = test_client._mock_app_svc
        svc.delete.side_effect = HTTPException(status_code=404, detail="Not found")

        resp = test_client.delete(f"/applications/{FAKE_APP_ID}")
        assert resp.status_code == 404
