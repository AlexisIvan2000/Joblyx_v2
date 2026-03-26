import logging
from contextlib import asynccontextmanager
from fastapi import FastAPI, Request

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s [%(name)s] %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from apscheduler.schedulers.asyncio import AsyncIOScheduler
from apscheduler.triggers.cron import CronTrigger
from slowapi import _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded
from core.rate_limit import limiter
from core.database import engine
from api.routers.auth import router as auth_router
from api.routers.users import router as users_router
from api.routers.roadmap import router as roadmap_router
from api.routers.applications import router as applications_router
from api.routers.assistant import router as assistant_router

scheduler = AsyncIOScheduler()


def _run_migrations():
    """Crée les tables si elles n'existent pas, puis applique les migrations Alembic."""
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
        # Base vide — créer toutes les tables puis stamp à head
        logging.getLogger(__name__).info("Empty database detected, creating tables...")
        from models.db_models import Base
        from sqlalchemy import create_engine as ce
        eng = ce(sync_url)
        Base.metadata.create_all(eng)
        eng.dispose()
        # Stamp pour qu'Alembic sache qu'on est à jour
        subprocess.run(["python", "-m", "alembic", "stamp", "head"], capture_output=True)
        logging.getLogger(__name__).info("Tables created and stamped at head")
    else:
        # Base existante — appliquer les migrations
        result = subprocess.run(
            ["python", "-m", "alembic", "upgrade", "head"],
            capture_output=True, text=True,
        )
        if result.returncode != 0:
            logging.getLogger(__name__).error("Alembic migration failed: %s", result.stderr)
        else:
            logging.getLogger(__name__).info("Alembic migrations applied")

@asynccontextmanager
async def lifespan(app: FastAPI):
    _run_migrations()
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

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth_router)
app.include_router(users_router)
app.include_router(roadmap_router)
app.include_router(applications_router)
app.include_router(assistant_router)

@app.get("/health")
async def health_check():
    return {"status": "ok"}

if __name__ == "__main__":
    import os
    import uvicorn
    port = int(os.getenv("PORT", "8000"))
    uvicorn.run(app, host="0.0.0.0", port=port)
