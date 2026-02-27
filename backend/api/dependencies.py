from core.database import supabase
from repositories.auth_repository import AuthRepository
from services.auth.email_password import EmailPasswordAuth

def get_auth_service() -> EmailPasswordAuth:
    repo = AuthRepository(supabase)
    return EmailPasswordAuth(repo)
