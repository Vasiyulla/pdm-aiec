"""Monitor router — GET /api/monitor and GET /api/history"""

from fastapi import APIRouter, Query
from app.services.device_manager import DeviceManager
from app.db.database import get_history
from app.models.schemas import MonitorResponse
import time

router = APIRouter()


@router.get("/monitor", response_model=MonitorResponse)
async def get_monitor():
    """Single-shot live reading. Use WebSocket /ws/monitor for streaming."""
    dm   = DeviceManager.get_instance()
    data = await dm.read_monitor()
    return MonitorResponse(
        timestamp=data.get("timestamp", time.time()),
        motor_state=data.get("motor_state", "STOPPED"),
        vfd=data.get("vfd"),
        pzem=data.get("pzem"),
        vfd_error=data.get("vfd_error"),
    )


@router.get("/history")
async def get_history_data(
    start_ts: float = Query(default=None, description="Start Unix timestamp"),
    end_ts:   float = Query(default=None, description="End Unix timestamp"),
    limit:    int   = Query(default=500, ge=1, le=10000),
):
    """Return historical readings from SQLite."""
    rows = await get_history(start_ts=start_ts, end_ts=end_ts, limit=limit)
    return {"count": len(rows), "rows": rows}