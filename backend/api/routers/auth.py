import logging
from urllib.parse import urlencode
from fastapi import APIRouter, Depends, Query, Request
from fastapi.responses import HTMLResponse, RedirectResponse
from models.schemas import UserCreate, UserLogin, LinkedInCallback, TokenResponse, RefreshToken, VerifyEmail, ForgotPassword, ResetPassword, ResendVerification, MessageResponse
from services.auth.email_password import EmailPasswordAuth
from services.auth.linkedin import LinkedInAuth
from services.users.users import UserService
from api.dependencies import get_auth_service, get_linkedin_auth, get_user_service
from core.rate_limit import limiter

router = APIRouter(prefix="/auth", tags=["auth"])


def _deep_link_page(deep_link_url: str) -> HTMLResponse:
    """Retourne une page HTML qui redirige une seule fois vers le deep link,
    puis affiche un message. Évite que le navigateur re-déclenche le redirect
    à chaque retour au premier plan."""
    html = f"""<!DOCTYPE html>
<html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Joblyx</title>
<style>body{{font-family:system-ui,sans-serif;display:flex;justify-content:center;align-items:center;
min-height:100vh;margin:0;background:#f5f5f5;color:#333;text-align:center}}
.card{{padding:2rem;border-radius:1rem;background:#fff;box-shadow:0 2px 8px rgba(0,0,0,.1)}}
</style></head><body><div class="card">
<h2>Redirection vers Joblyx...</h2>
<p id="msg">Ouverture de l'application...</p>
</div><script>
window.location.replace("{deep_link_url}");
setTimeout(function(){{document.getElementById("msg").textContent="Vous pouvez fermer cet onglet.";}},2000);
</script></body></html>"""
    return HTMLResponse(content=html)

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

@router.get("/linkedin/callback")
async def linkedin_callback(
    request: Request,
    code: str = Query(None),
    error: str = Query(None),
    auth: LinkedInAuth = Depends(get_linkedin_auth),
):
    """Callback OAuth LinkedIn — échange le code et redirige vers l'app avec les tokens."""
    logger = logging.getLogger(__name__)

    if error or not code:
        logger.warning("LinkedIn callback error: %s", error)
        params = urlencode({"error": error or "no_code"})
        return _deep_link_page(f"joblyx://auth?{params}")

    try:
        tokens = await auth.authenticate(code)
        params = urlencode({
            "access_token": tokens["access_token"],
            "refresh_token": tokens["refresh_token"],
        })
        return _deep_link_page(f"joblyx://auth?{params}")
    except Exception as e:
        logger.error("LinkedIn callback failed: %s", e)
        params = urlencode({"error": "auth_failed"})
        return _deep_link_page(f"joblyx://auth?{params}")

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
