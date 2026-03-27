from fastapi import APIRouter, Depends, File, HTTPException, UploadFile, status
from models.schemas import UpdateProfile, ChangePassword, SetPassword, ChangeEmail, VerifyEmailChange
from models.db_models import User
from services.auth.email_password import EmailPasswordAuth
from services.users.users import UserService
from api.dependencies import get_auth_service, get_user_service, get_current_user, get_r2_service
from services.storage.r2_service import R2Service

router = APIRouter(prefix="/users", tags=["users"])

@router.get("/me")
async def get_me(
    current_user: User = Depends(get_current_user),
    r2: R2Service = Depends(get_r2_service),
):
    # Si l'avatar est une URL externe (ex: ui-avatars), la retourner directement.
    # Si c'est un file_key R2 (ex: avatars/uuid.jpg), générer une URL signée.
    avatar_url = None
    if current_user.avatar_url:
        if current_user.avatar_url.startswith("http"):
            avatar_url = current_user.avatar_url
        else:
            try:
                avatar_url = await r2.get_avatar_url(current_user.avatar_url)
            except Exception:
                avatar_url = None

    return {
        "id": str(current_user.id),
        "first_name": current_user.first_name,
        "last_name": current_user.last_name,
        "email": current_user.email,
        "is_verified": current_user.is_verified,
        "avatar_url": avatar_url,
        "pending_email": current_user.pending_email,
        "has_password": current_user.password_hash is not None,
    }

@router.put("/me")
async def update_profile(
    body: UpdateProfile,
    current_user: User = Depends(get_current_user),
    svc: UserService = Depends(get_user_service),
):
    return await svc.update_profile(str(current_user.id), body)

@router.post("/me/change-password")
async def change_password(
    body: ChangePassword,
    current_user: User = Depends(get_current_user),
    svc: UserService = Depends(get_user_service),
):
    return await svc.change_password(str(current_user.id), body.current_password, body.new_password)

@router.post("/me/set-password")
async def set_password(
    body: SetPassword,
    current_user: User = Depends(get_current_user),
    svc: UserService = Depends(get_user_service),
):
    return await svc.set_password(str(current_user.id), body.new_password)

@router.post("/me/change-email")
async def change_email(
    body: ChangeEmail,
    current_user: User = Depends(get_current_user),
    svc: UserService = Depends(get_user_service),
):
    return await svc.request_email_change(str(current_user.id), body.new_email, body.password)

@router.post("/me/confirm-email-change")
async def confirm_email_change(
    body: VerifyEmailChange,
    current_user: User = Depends(get_current_user),
    svc: UserService = Depends(get_user_service),
):
    return await svc.confirm_email_change(str(current_user.id), body.code)

@router.post("/me/avatar")
async def upload_avatar(
    file: UploadFile = File(...),
    current_user: User = Depends(get_current_user),
    svc: UserService = Depends(get_user_service),
    r2: R2Service = Depends(get_r2_service),
):
    # Vérifier le type de fichier (images uniquement)
    allowed_types = ["image/jpeg", "image/png", "image/webp"]
    if not file.content_type or file.content_type not in allowed_types:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Only JPEG, PNG and WebP images are accepted",
        )

    content = await file.read()
    # Limite à 10 Mo
    if len(content) > 10 * 1024 * 1024:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="File too large (max 10 MB)",
        )

    user_id = str(current_user.id)

    # Supprimer l'ancien avatar si existant
    if current_user.avatar_url:
        try:
            old_key = current_user.avatar_url
            await r2.delete_avatar(old_key)
        except Exception:
            pass

    # Upload le nouvel avatar
    file_key = await r2.upload_avatar(user_id, content, file.content_type)
    avatar_url = await r2.get_avatar_url(file_key)

    # Sauvegarder le file_key dans la DB (pas l'URL signée qui expire)
    from models.schemas import UpdateProfile
    await svc.update_profile(user_id, UpdateProfile(avatar_url=file_key))

    return {"avatar_url": avatar_url, "file_key": file_key}


@router.delete("/me")
async def delete_account(
    email: str,
    current_user: User = Depends(get_current_user),
    svc: UserService = Depends(get_user_service),
    r2: R2Service = Depends(get_r2_service),
):
    """Supprime le compte, toutes les données et les fichiers R2."""
    user_id = str(current_user.id)

    # Vérifier que l'email correspond (confirmation)
    if current_user.email != email:
        raise HTTPException(status_code=400, detail="Email does not match your account")

    # Collecter les fichiers R2 AVANT de supprimer le user (CASCADE)
    from sqlalchemy import select
    from models.db_models import Application, CoachSession
    from core.database import get_db_session

    # Récupérer une session DB fraîche via le repo du service
    session = svc.repo.session

    # CVs des candidatures
    app_keys = await session.execute(
        select(Application.cv_file_key).where(
            Application.user_id == user_id,
            Application.cv_file_key.isnot(None),
        )
    )
    cv_keys = [r[0] for r in app_keys.all()]

    # CVs du coach
    coach_keys = await session.execute(
        select(CoachSession.cv_file_key).where(
            CoachSession.user_id == user_id,
            CoachSession.cv_file_key.isnot(None),
        )
    )
    cv_keys.extend(r[0] for r in coach_keys.all())

    # Avatar (file_key R2, pas une URL externe)
    avatar_key = None
    if current_user.avatar_url and not current_user.avatar_url.startswith("http"):
        avatar_key = current_user.avatar_url

    # Supprimer le user en DB (CASCADE supprime tout)
    await svc.delete_account(user_id, email)

    # Nettoyer R2 (best-effort, ne bloque pas si ça échoue)
    for key in cv_keys:
        try:
            await r2.delete_cv(key)
        except Exception:
            pass
    if avatar_key:
        try:
            await r2.delete_avatar(avatar_key)
        except Exception:
            pass

    return {"message": "Account deleted successfully"}


@router.post("/me/resend-email-verification")
async def resend_email_verification(
    current_user: User = Depends(get_current_user),
    auth: EmailPasswordAuth = Depends(get_auth_service),
):
    return await auth.resend_email_change_verification(str(current_user.id))
