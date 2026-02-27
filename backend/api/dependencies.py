from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from core.database import supabase
from core.security import Security
from repositories.auth_repository import AuthRepository
from services.auth.email_password import EmailPasswordAuth

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/auth/login")

def get_auth_service() -> EmailPasswordAuth:
    repo = AuthRepository(supabase)
    return EmailPasswordAuth(repo)

def get_current_user(token: str = Depends(oauth2_scheme)) -> dict:
    payload = Security.decode_token(token)
    if not payload or payload.get("type") != "access":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token",
            headers={"WWW-Authenticate": "Bearer"},
        )
    user_id = payload.get("sub")
    repo = AuthRepository(supabase)
    user = repo.get_user_by_id(user_id)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not found",
            headers={"WWW-Authenticate": "Bearer"},
        )
    return user
