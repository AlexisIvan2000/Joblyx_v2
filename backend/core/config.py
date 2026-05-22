from dotenv import load_dotenv
import os

load_dotenv()

# Récupère une variable d'env obligatoire ou crash explicite au démarrage.
def _require(name: str) -> str:
    value = os.getenv(name)
    if not value:
        raise RuntimeError(
            f"Missing required environment variable: {name}. "
            f"Set it before starting the app."
        )
    return value


JWT_SECRET_KEY = _require("JWT_SECRET_KEY")
JWT_ALGORITHM = os.getenv("JWT_ALGORITHM", "HS256")
ACCESS_TOKEN_EXPIRE_MINUTES = int(os.getenv("ACCESS_TOKEN_EXPIRE_MINUTES", "1440"))
REFRESH_TOKEN_EXPIRE_DAYS = int(os.getenv("REFRESH_TOKEN_EXPIRE_DAYS", "30"))

_raw_db_url = os.getenv("DB_URL") or os.getenv("DATABASE_URL")
if not _raw_db_url:
    raise RuntimeError(
        "Missing required environment variable: DATABASE_URL (or DB_URL). "
        "Set it before starting the app."
    )

if _raw_db_url.startswith("postgresql://"):
    DATABASE_URL = _raw_db_url.replace("postgresql://", "postgresql+asyncpg://", 1)
else:
    DATABASE_URL = _raw_db_url


OPENAI_API_KEY = _require("OPENAI_API_KEY")
OPENAI_MODEL_PRIMARY = "gpt-4o"        # Roadmap génération uniquement
OPENAI_MODEL_FAST = "gpt-4o-mini"      # Coach, simulateur, extraction skills


RESEND_API_KEY = _require("RESEND_API_KEY")
RESEND_FROM_EMAIL = os.getenv("RESEND_FROM_EMAIL", "support@joblyx.com")
RESEND_FROM_NAME  = os.getenv("RESEND_FROM_NAME", "Joblyx")


R2_ACCESS_KEY_ID = _require("R2_ACCESS_KEY_ID")
R2_SECRET_ACCESS_KEY = _require("R2_SECRET_ACCESS_KEY")
R2_ENDPOINT_URL = _require("R2_ENDPOINT_URL")
R2_BUCKET_NAME_RESUMES = os.getenv("R2_BUCKET_NAME_RESUMES", "cvs")
R2_BUCKET_NAME_IMAGES = os.getenv("R2_BUCKET_NAME_IMAGES", "avatar")

# CORS whitelist explicite des origines autorisées (séparées par virgules)
# Le mobile Flutter (app native) ne fait pas de CORS, donc liste vide = aucun navigateur n'accède à l'API
CORS_ORIGINS = [
    origin.strip()
    for origin in os.getenv("CORS_ORIGINS", "").split(",")
    if origin.strip()
]

FRONTEND_URL = os.getenv("FRONTEND_URL")

RAPIDAPI_KEY = os.getenv("RAPIDAPI_KEY")

LINKEDIN_CLIENT_ID = os.getenv("LINKEDIN_CLIENT_ID")
LINKEDIN_CLIENT_SECRET = os.getenv("LINKEDIN_CLIENT_SECRET")
LINKEDIN_REDIRECT_URI = os.getenv("LINKEDIN_REDIRECT_URI")

ADMIN_EMAIL = os.getenv("ADMIN_EMAIL")
ADMIN_PASSWORD = os.getenv("ADMIN_PASSWORD")

SENTRY_DSN = os.getenv("SENTRY_DSN")
SENTRY_ENVIRONMENT = os.getenv("SENTRY_ENVIRONMENT", "development")
SENTRY_TRACES_SAMPLE_RATE = float(os.getenv("SENTRY_TRACES_SAMPLE_RATE", "0.1"))
SENTRY_API_TOKEN = os.getenv("SENTRY_API_TOKEN")
SENTRY_API_URL = os.getenv("SENTRY_API_URL", "https://sentry.io/api/0")
SENTRY_ORG_SLUG = os.getenv("SENTRY_ORG_SLUG")
SENTRY_PROJECT_SLUG = os.getenv("SENTRY_PROJECT_SLUG")