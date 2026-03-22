from fastapi import APIRouter, Depends, File, HTTPException, UploadFile, status
from models.schemas import UpdateProfile, ChangePassword, ChangeEmail, VerifyEmailChange
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
    # Génère une URL signée si l'utilisateur a un avatar
    avatar_url = None
    if current_user.avatar_url:
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


@router.post("/me/resend-email-verification")
async def resend_email_verification(
    current_user: User = Depends(get_current_user),
    auth: EmailPasswordAuth = Depends(get_auth_service),
):
    return await auth.resend_email_change_verification(str(current_user.id))
