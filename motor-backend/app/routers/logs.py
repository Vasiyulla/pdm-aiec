"""Event log router — GET /api/logs"""

from fastapi import APIRouter, Query
from app.db.database import get_events

router = APIRouter()


@router.get("/logs")
async def get_logs(limit: int = Query(default=100, ge=1, le=1000)):
    events = await get_events(limit=limit)
    return {"count": len(events), "events": events}
