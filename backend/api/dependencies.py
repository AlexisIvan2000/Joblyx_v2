from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy.ext.asyncio import AsyncSession
from core.database import get_db_session
from core.security import Security
from repositories.auth_repository import AuthRepository
from repositories.refresh_token_repository import RefreshTokenRepository
from services.emailing.otp_service import OtpService
from services.auth.email_password import EmailPasswordAuth
from services.auth.linkedin import LinkedInAuth
from services.users.users import UserService
from services.roadmap.roadmap_service import RoadmapService
from repositories.application_repository import ApplicationRepository
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
    return user
