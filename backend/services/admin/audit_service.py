from sqlalchemy.ext.asyncio import AsyncSession

from repositories.audit_log_repository import AuditLogRepository


class AdminAuditService:
    def __init__(self, session: AsyncSession):
        self.session = session
        self.audit_repo = AuditLogRepository(session)

    async def get_audit_log(
        self,
        *,
        page: int = 1,
        page_size: int = 100,
        action: str | None = None,
        target_id: str | None = None,
        search: str | None = None,
    ) -> dict:
        offset = (page - 1) * page_size
        entries, total = await self.audit_repo.list_recent(
            offset=offset, limit=page_size,
            action=action, target_id=target_id, search=search,
        )
        return {"entries": entries, "total": total, "page": page, "page_size": page_size}
