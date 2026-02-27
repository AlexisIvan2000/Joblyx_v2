from fastapi import APIRouter, Depends
from models.schemas import UserCreate, UserLogin, TokenResponse, RefreshToken, VerifyEmail, ForgotPassword, ResetPassword, ResendVerification
from services.auth.email_password import EmailPasswordAuth
from services.users.users import UserService
from api.dependencies import get_auth_service, get_user_service

router = APIRouter(prefix="/auth", tags=["auth"])

@router.post("/register", response_model=TokenResponse)
def register(user: UserCreate, auth: EmailPasswordAuth = Depends(get_auth_service)):
    return auth.register_user(user)

@router.post("/login", response_model=TokenResponse)
def login(user: UserLogin, auth: EmailPasswordAuth = Depends(get_auth_service)):
    return auth.login_user(user)

@router.post("/verify-email")
def verify_email(body: VerifyEmail, auth: EmailPasswordAuth = Depends(get_auth_service)):
    return auth.verify_email(body.token)

@router.post("/refresh")
def refresh(body: RefreshToken, auth: EmailPasswordAuth = Depends(get_auth_service)):
    return auth.refresh_access_token(body.refresh_token)

@router.post("/logout")
def logout(body: RefreshToken, auth: EmailPasswordAuth = Depends(get_auth_service)):
    return auth.logout_user(body.refresh_token)

@router.post("/resend-verification")
def resend_verification(body: ResendVerification, auth: EmailPasswordAuth = Depends(get_auth_service)):
    return auth.resend_verification_email(body.email)

@router.post("/forgot-password")
def forgot_password(body: ForgotPassword, svc: UserService = Depends(get_user_service)):
    return svc.forgot_password(body.email)

@router.post("/reset-password")
def reset_password(body: ResetPassword, svc: UserService = Depends(get_user_service)):
    return svc.reset_password(body.token, body.new_password)
