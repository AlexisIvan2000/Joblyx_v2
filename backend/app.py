from fastapi import FastAPI
from api.routers.auth import router as auth_router
from api.routers.users import router as users_router

app = FastAPI(title="Joblyx API")

app.include_router(auth_router)
app.include_router(users_router)
