from fastapi import APIRouter, Depends, Query

from api.v1.admin.dependencies import get_admin_audit_service
from services.admin.audit_service import AdminAuditService
from models.api_schemas import AdminAuditLogResponse

router = APIRouter(tags=["admin"])


@router.get("/audit-log", response_model=AdminAuditLogResponse)
async def get_audit_log(
    page: int = Query(1, ge=1),
    limit: int = Query(100, ge=1, le=500),
    action: str | None = None,
    target_id: str | None = None,
    search: str | None = None,
    svc: AdminAuditService = Depends(get_admin_audit_service),
):
    result = await svc.get_audit_log(
        page=page, page_size=limit,
        action=action, target_id=target_id, search=search,
    )
    return {
        "entries": [
            {
                "id": str(e.id),
                "admin_user_id": str(e.admin_user_id) if e.admin_user_id else None,
                "action": e.action,
                "target_type": e.target_type,
                "target_id": e.target_id,
                "payload": e.payload,
                "created_at": e.created_at.isoformat() if e.created_at else "",
            }
            for e in result["entries"]
        ],
        "total": result["total"],
        "page": result["page"],
        "page_size": result["page_size"],
    }
