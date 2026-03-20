import json
from fastapi import APIRouter, Depends, File, Form, Query, UploadFile, HTTPException
from models.schemas import ApplicationCreate, ApplicationUpdate, ApplicationResponse
from models.db_models import User
from services.applications.application_service import ApplicationService
from api.dependencies import get_application_service, get_current_user

router = APIRouter(prefix="/applications", tags=["applications"])


def _to_response(app, cv_url: str | None = None) -> ApplicationResponse:
    return ApplicationResponse(
        id=str(app.id),
        company_name=app.company_name,
        job_title=app.job_title,
        job_url=app.job_url,
        job_description=app.job_description,
        status=app.status,
        cv_file_key=app.cv_file_key,
        cv_url=cv_url,
        notes=app.notes,
        applied_at=app.applied_at.isoformat() if app.applied_at else None,
        updated_at=app.updated_at.isoformat() if app.updated_at else None,
    )


@router.post("", response_model=ApplicationResponse)
async def create_application(
    data: str = Form(...),
    cv: UploadFile | None = File(None),
    current_user: User = Depends(get_current_user),
    svc: ApplicationService = Depends(get_application_service),
):
    # "Crée une candidature avec CV optionnel (multipart).
    try:
        body = ApplicationCreate(**json.loads(data))
    except (json.JSONDecodeError, ValueError) as e:
        raise HTTPException(status_code=400, detail=str(e))

    cv_bytes = None
    cv_filename = None
    if cv:
        if not cv.content_type or "pdf" not in cv.content_type:
            raise HTTPException(status_code=400, detail="Only PDF files are accepted")
        cv_bytes = await cv.read()
        if len(cv_bytes) > 5 * 1024 * 1024:
            raise HTTPException(status_code=400, detail="File too large (max 5 MB)")
        cv_filename = cv.filename or "cv.pdf"

    app = await svc.create(
        user_id=str(current_user.id),
        data=body.model_dump(exclude_none=True),
        cv_bytes=cv_bytes,
        cv_filename=cv_filename,
    )
    return _to_response(app)


@router.get("", response_model=list[ApplicationResponse])
async def list_applications(
    status: str | None = Query(None),
    current_user: User = Depends(get_current_user),
    svc: ApplicationService = Depends(get_application_service),
):
    apps = await svc.get_all(str(current_user.id), status_filter=status)
    return [_to_response(a) for a in apps]


@router.get("/{app_id}", response_model=ApplicationResponse)
async def get_application(
    app_id: str,
    current_user: User = Depends(get_current_user),
    svc: ApplicationService = Depends(get_application_service),
):
    app = await svc.get_by_id(app_id, str(current_user.id))
    # Générer l'URL signée du CV si présent
    cv_url = None
    if app.cv_file_key:
        cv_url = await svc.get_cv_url(app_id, str(current_user.id))
    return _to_response(app, cv_url=cv_url)


@router.put("/{app_id}", response_model=ApplicationResponse)
async def update_application(
    app_id: str,
    body: ApplicationUpdate,
    current_user: User = Depends(get_current_user),
    svc: ApplicationService = Depends(get_application_service),
):
    app = await svc.update(app_id, str(current_user.id), body.model_dump())
    return _to_response(app)


@router.delete("/{app_id}")
async def delete_application(
    app_id: str,
    current_user: User = Depends(get_current_user),
    svc: ApplicationService = Depends(get_application_service),
):
    await svc.delete(app_id, str(current_user.id))
    return {"message": "Application deleted"}
