from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy.ext.asyncio import AsyncSession
from core.database import get_db_session
from core.exceptions import AdminAccessRequired, SuperAdminAccessRequired, UserBanned
from core.security import Security
from repositories.auth_repository import AuthRepository
from repositories.refresh_token_repository import RefreshTokenRepository
from services.emailing.otp_service import OtpService
from services.auth.email_password import EmailPasswordAuth
from services.auth.linkedin import LinkedInAuth
from services.users.users import UserService
from services.roadmap.roadmap_service import RoadmapService
from repositories.application_repository import ApplicationRepository
from services.admin.admin_service import AdminService
from services.admin.sentry_service import SentryService
from services.applications.application_service import ApplicationService
from services.storage.r2_service import R2Service

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/auth/login")

async def get_auth_service(session: AsyncSession = Depends(get_db_session)) -> EmailPasswordAuth:
    auth_repo = AuthRepository(session)
    rt_repo = RefreshTokenRepository(session)
    otp_svc = OtpService(auth_repo)
    return EmailPasswordAuth(auth_repo, rt_repo, otp_svc)

async def get_linkedin_auth(session: AsyncSession = Depends(get_db_session)) -> LinkedInAuth:
    auth_repo = AuthRepository(session)
    rt_repo = RefreshTokenRepository(session)
    return LinkedInAuth(auth_repo, rt_repo)

async def get_user_service(session: AsyncSession = Depends(get_db_session)) -> UserService:
    repo = AuthRepository(session)
    rt_repo = RefreshTokenRepository(session)
    otp_svc = OtpService(repo)
    return UserService(repo, otp_svc, rt_repo)

async def get_roadmap_service(session: AsyncSession = Depends(get_db_session)) -> RoadmapService:
    return RoadmapService(session)

async def get_application_service(session: AsyncSession = Depends(get_db_session)) -> ApplicationService:
    repo = ApplicationRepository(session)
    r2 = R2Service()
    return ApplicationService(repo, r2)

def get_r2_service() -> R2Service:
    return R2Service()


async def get_admin_service(session: AsyncSession = Depends(get_db_session)) -> AdminService:
    return AdminService(session)


def get_sentry_service() -> SentryService:
    return SentryService()

async def get_current_user(
    token: str = Depends(oauth2_scheme),
    session: AsyncSession = Depends(get_db_session),
):
    payload = Security.decode_token(token)
    if not payload or payload.get("type") != "access":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token",
            headers={"WWW-Authenticate": "Bearer"},
        )
    user_id = payload.get("sub")
    repo = AuthRepository(session)
    user = await repo.get_user_by_id(user_id)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not found",
            headers={"WWW-Authenticate": "Bearer"},
        )
    # Rejette toute requête d'un compte désactivé couvre les tokens encore valides au moment de la désactivation
    if not user.is_active:
        raise UserBanned()

    # Enrichit Sentry avec le contexte user toute erreur sur cette requête sera attribuée
    try:
        import sentry_sdk
        sentry_sdk.set_user({
            "id": str(user.id),
            "email": user.email,
            "role": user.role,
        })
    except ImportError:
        pass  # Sentry non installé, on continue sans

    return user


async def require_admin(current_user=Depends(get_current_user)):
    """Dépendance pour les routes /admin/*  exige le rôle admin ou super_admin."""
    if current_user.role not in ("admin", "super_admin"):
        raise AdminAccessRequired()
    return current_user


async def require_super_admin(current_user=Depends(get_current_user)):
    """Dépendance pour les actions critiques (modif d'un autre admin)  exige super_admin."""
    if current_user.role != "super_admin":
        raise SuperAdminAccessRequired()
    return current_user
