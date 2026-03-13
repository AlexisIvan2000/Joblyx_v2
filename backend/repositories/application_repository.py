from sqlalchemy import select, update, delete
from sqlalchemy.ext.asyncio import AsyncSession

from models.db_models import Application


class ApplicationRepository:
    def __init__(self, session: AsyncSession):
        self.session = session

    async def create(self, user_id: str, data: dict) -> Application:
        app = Application(user_id=user_id, **data)
        self.session.add(app)
        await self.session.flush()
        return app

    async def get_by_id(self, app_id: str, user_id: str) -> Application | None:
        result = await self.session.execute(
            select(Application).where(
                Application.id == app_id,
                Application.user_id == user_id,
            )
        )
        return result.scalar_one_or_none()

    async def get_all_by_user(
        self, user_id: str, status_filter: str | None = None
    ) -> list[Application]:
        query = select(Application).where(Application.user_id == user_id)
        if status_filter:
            query = query.where(Application.status == status_filter)
        query = query.order_by(Application.applied_at.desc())
        result = await self.session.execute(query)
        return list(result.scalars().all())

    async def update(self, app_id: str, user_id: str, data: dict) -> Application | None:
        # Vérifier que la candidature appartient à l'utilisateur
        existing = await self.get_by_id(app_id, user_id)
        if not existing:
            return None

        await self.session.execute(
            update(Application)
            .where(Application.id == app_id, Application.user_id == user_id)
            .values(**data)
        )
        await self.session.flush()
        # Expirer le cache pour forcer la relecture depuis la DB
        await self.session.refresh(existing)
        return existing

    async def delete(self, app_id: str, user_id: str) -> Application | None:
        existing = await self.get_by_id(app_id, user_id)
        if not existing:
            return None

        await self.session.execute(
            delete(Application).where(
                Application.id == app_id,
                Application.user_id == user_id,
            )
        )
        await self.session.flush()
        return existing
