"""Repository pour les logs d'actions admin (ban, delete, promote, etc.)."""

from sqlalchemy import desc, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from models.db import AuditLog


class AuditLogRepository:
    def __init__(self, session: AsyncSession):
        self.session = session

    async def create(
        self,
        admin_id: str | None,
        action: str,
        target_type: str | None = None,
        target_id: str | None = None,
        payload: dict | None = None,
    ) -> AuditLog:
        entry = AuditLog(
            admin_user_id=admin_id,
            action=action,
            target_type=target_type,
            target_id=target_id,
            payload=payload,
        )
        self.session.add(entry)
        await self.session.flush()
        return entry

    async def list_recent(
        self,
        *,
        offset: int = 0,
        limit: int = 100,
        action: str | None = None,
        admin_id: str | None = None,
        target_id: str | None = None,
        search: str | None = None,
    ) -> tuple[list[AuditLog], int]:
        query = select(AuditLog)
        count_query = select(func.count()).select_from(AuditLog)

        conditions = []
        if action is not None:
            conditions.append(AuditLog.action == action)
        if admin_id is not None:
            conditions.append(AuditLog.admin_user_id == admin_id)
        if target_id is not None:
            conditions.append(AuditLog.target_id == target_id)
        if search:
            # Recherche ILIKE sur l'email cible stocké dans payload JSONB
            pattern = f"%{search}%"
            conditions.append(AuditLog.payload["target_email"].astext.ilike(pattern))

        for cond in conditions:
            query = query.where(cond)
            count_query = count_query.where(cond)

        query = query.order_by(desc(AuditLog.created_at)).offset(offset).limit(limit)

        rows_result = await self.session.execute(query)
        count_result = await self.session.execute(count_query)
        return list(rows_result.scalars().all()), int(count_result.scalar() or 0)
