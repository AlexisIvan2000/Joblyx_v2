from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from apscheduler.schedulers.asyncio import AsyncIOScheduler
from apscheduler.triggers.cron import CronTrigger
from core.database import engine
from api.routers.auth import router as auth_router
from api.routers.users import router as users_router
from api.routers.onboarding import router as onboarding_router
from api.routers.roadmap import router as roadmap_router
from api.routers.applications import router as applications_router

scheduler = AsyncIOScheduler()


@asynccontextmanager
async def lifespan(app: FastAPI):
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

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth_router)
app.include_router(users_router)
app.include_router(onboarding_router)
app.include_router(roadmap_router)
app.include_router(applications_router)

@app.route("/health", methods=["GET"])
async def health_check():
    return {"status": "ok"}
