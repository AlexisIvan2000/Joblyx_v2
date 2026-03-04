from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy.ext.asyncio import AsyncSession
from core.database import get_db_session
from core.security import Security
from repositories.auth_repository import AuthRepository
from repositories.refresh_token_repository import RefreshTokenRepository
from repositories.career_repository import CareerRepository
from services.auth.email_password import EmailPasswordAuth
from services.users.users import UserService
from services.onboarding.onboarding_service import OnboardingService

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/auth/login")

async def get_auth_service(session: AsyncSession = Depends(get_db_session)) -> EmailPasswordAuth:
    auth_repo = AuthRepository(session)
    rt_repo = RefreshTokenRepository(session)
    return EmailPasswordAuth(auth_repo, rt_repo)

async def get_user_service(session: AsyncSession = Depends(get_db_session)) -> UserService:
    repo = AuthRepository(session)
    return UserService(repo)

async def get_onboarding_service(session: AsyncSession = Depends(get_db_session)) -> OnboardingService:
    repo = CareerRepository(session)
    return OnboardingService(repo)

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
