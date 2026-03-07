from fastapi import HTTPException, status
from repositories.application_repository import ApplicationRepository
from services.storage.r2_service import R2Service
from models.db_models import Application


class ApplicationService:
    def __init__(self, repo: ApplicationRepository, r2: R2Service):
        self.repo = repo
        self.r2 = r2

    async def create(
        self,
        user_id: str,
        data: dict,
        cv_bytes: bytes | None = None,
        cv_filename: str | None = None,
    ) -> Application:
        # Upload du CV si fourni
        if cv_bytes and cv_filename:
            file_key = await self.r2.upload_cv(user_id, cv_bytes, cv_filename)
            data["cv_file_key"] = file_key

        return await self.repo.create(user_id, data)

    async def get_by_id(self, app_id: str, user_id: str) -> Application:
        app = await self.repo.get_by_id(app_id, user_id)
        if not app:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Application not found",
            )
        return app

    async def get_all(
        self, user_id: str, status_filter: str | None = None
    ) -> list[Application]:
        return await self.repo.get_all_by_user(user_id, status_filter)

    async def update(self, app_id: str, user_id: str, data: dict) -> Application:
        # Retirer les champs None
        data = {k: v for k, v in data.items() if v is not None}
        if not data:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="No fields to update",
            )

        app = await self.repo.update(app_id, user_id, data)
        if not app:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Application not found",
            )
        return app

    async def delete(self, app_id: str, user_id: str) -> None:
        app = await self.repo.delete(app_id, user_id)
        if not app:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Application not found",
            )
        # Supprimer le CV de R2 si existant
        if app.cv_file_key:
            await self.r2.delete_cv(app.cv_file_key)

    async def get_cv_url(self, app_id: str, user_id: str) -> str:
        app = await self.get_by_id(app_id, user_id)
        if not app.cv_file_key:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="No CV attached to this application",
            )
        return await self.r2.get_cv_url(app.cv_file_key)
