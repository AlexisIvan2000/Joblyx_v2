from fastapi import FastAPI
from api.routers.auth import router as auth_router

app = FastAPI(title="Joblyx API")

app.include_router(auth_router)
