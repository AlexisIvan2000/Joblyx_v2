from fastapi import APIRouter, Depends, Request
from models.schemas import UserCreate, UserLogin, LinkedInCallback, TokenResponse, RefreshToken, VerifyEmail, ForgotPassword, ResetPassword, ResendVerification, MessageResponse
from services.auth.email_password import EmailPasswordAuth
from services.auth.linkedin import LinkedInAuth
from services.users.users import UserService
from api.dependencies import get_auth_service, get_linkedin_auth, get_user_service
from core.rate_limit import limiter

router = APIRouter(prefix="/auth", tags=["auth"])

@router.post("/register", response_model=MessageResponse)
@limiter.limit("5/minute")
async def register(request: Request, user: UserCreate, auth: EmailPasswordAuth = Depends(get_auth_service)):
    return await auth.register_user(user)

@router.post("/login", response_model=TokenResponse)
@limiter.limit("5/minute")
async def login(request: Request, user: UserLogin, auth: EmailPasswordAuth = Depends(get_auth_service)):
    return await auth.login_user(user)

@router.post("/verify-email", response_model=TokenResponse)
@limiter.limit("5/minute")
async def verify_email(request: Request, body: VerifyEmail, auth: EmailPasswordAuth = Depends(get_auth_service)):
    return await auth.verify_email(body.email, body.code)

@router.post("/refresh")
@limiter.limit("10/minute")
async def refresh(request: Request, body: RefreshToken, auth: EmailPasswordAuth = Depends(get_auth_service)):
    return await auth.refresh_access_token(body.refresh_token)

@router.post("/logout")
async def logout(body: RefreshToken, auth: EmailPasswordAuth = Depends(get_auth_service)):
    return await auth.logout_user(body.refresh_token)

@router.post("/linkedin", response_model=TokenResponse)
@limiter.limit("10/minute")
async def linkedin_login(request: Request, body: LinkedInCallback, auth: LinkedInAuth = Depends(get_linkedin_auth)):
    return await auth.authenticate(body.code)

@router.post("/resend-verification")
@limiter.limit("3/minute")
async def resend_verification(request: Request, body: ResendVerification, auth: EmailPasswordAuth = Depends(get_auth_service)):
    return await auth.resend_verification_email(body.email)

@router.post("/forgot-password")
@limiter.limit("3/minute")
async def forgot_password(request: Request, body: ForgotPassword, svc: UserService = Depends(get_user_service)):
    return await svc.forgot_password(body.email)

@router.post("/reset-password")
@limiter.limit("5/minute")
async def reset_password(request: Request, body: ResetPassword, svc: UserService = Depends(get_user_service)):
    return await svc.reset_password(body.email, body.code, body.new_password)
