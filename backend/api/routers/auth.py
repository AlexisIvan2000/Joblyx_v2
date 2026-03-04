from fastapi import APIRouter, Depends
from models.schemas import UserCreate, UserLogin, TokenResponse, RefreshToken, VerifyEmail, ForgotPassword, ResetPassword, ResendVerification, MessageResponse
from services.auth.email_password import EmailPasswordAuth
from services.users.users import UserService
from api.dependencies import get_auth_service, get_user_service

router = APIRouter(prefix="/auth", tags=["auth"])

@router.post("/register", response_model=MessageResponse)
async def register(user: UserCreate, auth: EmailPasswordAuth = Depends(get_auth_service)):
    return await auth.register_user(user)

@router.post("/login", response_model=TokenResponse)
async def login(user: UserLogin, auth: EmailPasswordAuth = Depends(get_auth_service)):
    return await auth.login_user(user)

@router.post("/verify-email", response_model=TokenResponse)
async def verify_email(body: VerifyEmail, auth: EmailPasswordAuth = Depends(get_auth_service)):
    return await auth.verify_email(body.email, body.code)

@router.post("/refresh")
async def refresh(body: RefreshToken, auth: EmailPasswordAuth = Depends(get_auth_service)):
    return await auth.refresh_access_token(body.refresh_token)

@router.post("/logout")
async def logout(body: RefreshToken, auth: EmailPasswordAuth = Depends(get_auth_service)):
    return await auth.logout_user(body.refresh_token)

@router.post("/resend-verification")
async def resend_verification(body: ResendVerification, auth: EmailPasswordAuth = Depends(get_auth_service)):
    return await auth.resend_verification_email(body.email)

@router.post("/forgot-password")
async def forgot_password(body: ForgotPassword, svc: UserService = Depends(get_user_service)):
    return await svc.forgot_password(body.email)

@router.post("/reset-password")
async def reset_password(body: ResetPassword, svc: UserService = Depends(get_user_service)):
    return await svc.reset_password(body.email, body.code, body.new_password)
