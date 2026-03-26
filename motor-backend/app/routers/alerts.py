"""Alerts router — GET /api/alerts  POST /api/alerts/{id}/ack"""

from fastapi import APIRouter, HTTPException, Query
from app.services.alert_engine import AlertEngine

router = APIRouter()


@router.get("/alerts")
async def get_alerts(
    include_history: bool = Query(default=True),
    limit: int           = Query(default=50, ge=1, le=200),
):
    engine  = AlertEngine.get_instance()
    active  = engine.get_active()
    history = engine.get_history(limit=limit) if include_history else []
    return {
        "active":  active,
        "history": history,
        "active_count": len(active),
    }


@router.post("/alerts/{alert_id}/ack")
async def acknowledge_alert(alert_id: str):
    engine = AlertEngine.get_instance()
    ok = engine.acknowledge(alert_id)
    if not ok:
        raise HTTPException(status_code=404, detail="Alert not found")
    return {"success": True, "alert_id": alert_id}
