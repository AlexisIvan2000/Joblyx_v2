import logging
from contextlib import asynccontextmanager
from fastapi import FastAPI, Request

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s [%(name)s] %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)

# Initialisation Sentry — avant tous les autres imports pour capturer même les erreurs de boot
from core.config import (
    CORS_ORIGINS,
    SENTRY_DSN,
    SENTRY_ENVIRONMENT,
    SENTRY_TRACES_SAMPLE_RATE,
)

if SENTRY_DSN:
    import sentry_sdk
    from sentry_sdk.integrations.fastapi import FastApiIntegration
    from sentry_sdk.integrations.starlette import StarletteIntegration
    from sentry_sdk.integrations.sqlalchemy import SqlalchemyIntegration

    sentry_sdk.init(
        dsn=SENTRY_DSN,
        environment=SENTRY_ENVIRONMENT,
        traces_sample_rate=SENTRY_TRACES_SAMPLE_RATE,
        integrations=[
            FastApiIntegration(transaction_style="endpoint"),
            StarletteIntegration(),
            SqlalchemyIntegration(),
        ],
        # Ne pas envoyer les emails/IPs/headers sensibles par défaut
        send_default_pii=False,
    )
    logging.getLogger(__name__).info("Sentry initialized: env=%s", SENTRY_ENVIRONMENT)

from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from apscheduler.schedulers.asyncio import AsyncIOScheduler
from apscheduler.triggers.cron import CronTrigger
from slowapi import _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded
from core.rate_limit import limiter
from core.database import engine
from core.exceptions import DomainError
from api.v1 import v1_router
from api.v1.client import router as client_router
from api.middlewares import register_legacy_route_logger

scheduler = AsyncIOScheduler()

# Crée les tables si elles n'existent pas, puis applique les migrations Alembic.
def _run_migrations():
    import subprocess
    from sqlalchemy import inspect, create_engine
    from core.config import DATABASE_URL

    # Connexion synchrone pour inspecter la base
    sync_url = DATABASE_URL.replace("+asyncpg", "")
    sync_engine = create_engine(sync_url)
    inspector = inspect(sync_engine)
    tables = inspector.get_table_names()
    sync_engine.dispose()

    if "users" not in tables:
        logging.getLogger(__name__).info("Empty database detected, creating tables...")
        from models.db_models import Base
        from sqlalchemy import create_engine as ce
        eng = ce(sync_url)
        Base.metadata.create_all(eng)
        eng.dispose()
        subprocess.run(["python", "-m", "alembic", "stamp", "head"], capture_output=True)
        logging.getLogger(__name__).info("Tables created and stamped at head")
    else:
        result = subprocess.run(
            ["python", "-m", "alembic", "upgrade", "head"],
            capture_output=True, text=True,
        )
        if result.returncode != 0:
            logging.getLogger(__name__).error("Alembic migration failed: %s", result.stderr)
        else:
            logging.getLogger(__name__).info("Alembic migrations applied")

async def _ensure_admin_account():
    from core.config import ADMIN_EMAIL, ADMIN_PASSWORD
    from core.database import AsyncSessionLocal
    from core.security import Security
    from repositories.auth_repository import AuthRepository

    logger = logging.getLogger(__name__)

    if not ADMIN_EMAIL or not ADMIN_PASSWORD:
        logger.warning("Admin seed skipped: missing ADMIN_EMAIL or ADMIN_PASSWORD")
        return

    async with AsyncSessionLocal() as session:
        repo = AuthRepository(session)
        existing = await repo.get_user_by_email(ADMIN_EMAIL)

        if existing:
            if existing.role != "super_admin":
                await repo.update_user(str(existing.id), {"role": "super_admin"})
                await session.commit()
                logger.info("Admin promoted: email=%s user_id=%s", ADMIN_EMAIL, existing.id)
            else:
                logger.info("Admin already exists: email=%s", ADMIN_EMAIL)
            return

        # Création d'un nouveau compte super_admin pré-vérifié
        password_hash = Security.hash_password(ADMIN_PASSWORD)
        new_admin = await repo.create_user({
            "first_name": "Admin",
            "last_name": "Joblyx",
            "email": ADMIN_EMAIL,
            "password_hash": password_hash,
            "is_verified": True,
            "role": "super_admin",
        })
        await session.commit()
        logger.info("Admin account created: email=%s user_id=%s", ADMIN_EMAIL, new_admin.id)


@asynccontextmanager
async def lifespan(app: FastAPI):
    _run_migrations()
    await _ensure_admin_account()
    from cron.refresh_market_cache import refresh_market_cache

    scheduler.add_job(
        refresh_market_cache,
        trigger=CronTrigger(hour="2,14", minute=0),
        id="refresh_market_cache",
        replace_existing=True,
    )
    scheduler.start()
    yield
    scheduler.shutdown(wait=False)
    await engine.dispose()


app = FastAPI(title="Joblyx API", lifespan=lifespan)

# Enregistre le limiter sur l'app
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)


# Traduit toute DomainError levée par les services en réponse JSON normalisée
@app.exception_handler(DomainError)
async def domain_exception_handler(request: Request, exc: DomainError):
    # On capture aussi les 4xx dans Sentry pour spotter brute force, anomalies, etc.
    if SENTRY_DSN:
        import sentry_sdk
        with sentry_sdk.push_scope() as scope:
            scope.set_tag("error_code", exc.error_code)
            scope.set_tag("status_code", str(exc.status_code))
            scope.set_context("request", {
                "method": request.method,
                "path": request.url.path,
            })
            # Level "warning" pour les 4xx (erreurs client attendues), "error" pour les 5xx
            scope.level = "warning" if 400 <= exc.status_code < 500 else "error"
            sentry_sdk.capture_exception(exc)

    return JSONResponse(
        status_code=exc.status_code,
        content={
            "error": exc.error_code,
            "message": exc.message,
            "details": exc.details,
        },
    )

app.add_middleware(
    CORSMiddleware,
    allow_origins=CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
    allow_headers=["Authorization", "Content-Type"],
)

# API versionnée, toutes les nouvelles intégrations doivent pointer vers /v1/...
app.include_router(v1_router)

# Compat legacy pour l'app mobile en production qui pointe vers la racine
# Caché de Swagger (include_in_schema=False), à retirer quand le mobile aura migré vers /v1/
app.include_router(client_router, include_in_schema=False)

register_legacy_route_logger(app)


@app.get("/health")
async def health_check():
    return {"status": "ok"}

# @app.get("/sentry-debug")
# async def trigger_error():
#     division_by_zero = 1 / 0

if __name__ == "__main__":
    import os
    import uvicorn
    port = int(os.getenv("PORT", "8000"))
    uvicorn.run(app, host="0.0.0.0", port=port)
