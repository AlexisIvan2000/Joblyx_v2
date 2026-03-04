from fastapi import APIRouter, Depends
from models.schemas import UpdateProfile, ChangePassword, ChangeEmail, VerifyEmailChange
from models.db_models import User
from services.auth.email_password import EmailPasswordAuth
from services.users.users import UserService
from api.dependencies import get_auth_service, get_user_service, get_current_user

router = APIRouter(prefix="/users", tags=["users"])

@router.get("/me")
async def get_me(current_user: User = Depends(get_current_user)):
    return {
        "id": str(current_user.id),
        "first_name": current_user.first_name,
        "last_name": current_user.last_name,
        "email": current_user.email,
        "is_verified": current_user.is_verified,
        "avatar_url": current_user.avatar_url,
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

@router.post("/me/resend-email-verification")
async def resend_email_verification(
    current_user: User = Depends(get_current_user),
    auth: EmailPasswordAuth = Depends(get_auth_service),
):
    return await auth.resend_email_change_verification(str(current_user.id))
