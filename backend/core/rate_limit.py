from fastapi import Request
from slowapi import Limiter
from slowapi.util import get_remote_address
from core.security import Security

# Extrait le user_id du JWT Bearer token pour le rate limiting par user
def get_user_id_from_jwt(request: Request) -> str:
    auth_header = request.headers.get("authorization", "")
    if auth_header.startswith("Bearer "):
        token = auth_header[7:]
        payload = Security.decode_token(token)
        if payload and payload.get("sub"):
            return payload["sub"]
    return get_remote_address(request)


# Instance globale du rate limiter  clé par défaut = IP du client
limiter = Limiter(key_func=get_remote_address)
