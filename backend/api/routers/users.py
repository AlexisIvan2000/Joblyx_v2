from fastapi import APIRouter, Depends
from models.schemas import UpdateProfile, ChangePassword, ChangeEmail, VerifyEmail
from services.auth.email_password import EmailPasswordAuth
from services.users.users import UserService
from api.dependencies import get_auth_service, get_user_service, get_current_user

router = APIRouter(prefix="/users", tags=["users"])

@router.get("/me")
def get_me(current_user: dict = Depends(get_current_user)):
    user = {k: v for k, v in current_user.items() if k != "password_hash"}
    return user

@router.put("/me")
def update_profile(
    body: UpdateProfile,
    current_user: dict = Depends(get_current_user),
    svc: UserService = Depends(get_user_service),
):
    return svc.update_profile(str(current_user["id"]), body)

@router.post("/me/change-password")
def change_password(
    body: ChangePassword,
    current_user: dict = Depends(get_current_user),
    svc: UserService = Depends(get_user_service),
):
    return svc.change_password(str(current_user["id"]), body.current_password, body.new_password)

@router.post("/me/change-email")
def change_email(
    body: ChangeEmail,
    current_user: dict = Depends(get_current_user),
    svc: UserService = Depends(get_user_service),
):
    return svc.request_email_change(str(current_user["id"]), body.new_email, body.password)

@router.post("/me/confirm-email-change")
def confirm_email_change(
    body: VerifyEmail,
    svc: UserService = Depends(get_user_service),
):
    return svc.confirm_email_change(body.token)

@router.post("/me/resend-email-verification")
def resend_email_verification(
    current_user: dict = Depends(get_current_user),
    auth: EmailPasswordAuth = Depends(get_auth_service),
):
    return auth.resend_email_change_verification(str(current_user["id"]))
