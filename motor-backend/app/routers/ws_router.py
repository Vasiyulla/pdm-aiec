"""
WebSocket Router
================
WS /ws/monitor  — streams live VFD + PZEM data every 500 ms
WS /ws/alerts   — pushes alert events in real time
"""

from fastapi import APIRouter, WebSocket, WebSocketDisconnect
from app.ws.connection_manager import ws_monitor_manager, ws_alert_manager
import logging

logger = logging.getLogger("motor.ws_router")
router = APIRouter()


@router.websocket("/ws/monitor")
async def ws_monitor(ws: WebSocket):
    await ws_monitor_manager.connect(ws)
    try:
        while True:
            # Keep the connection alive; data is pushed by the PollerService.
            # We still receive pings/close frames from the client.
            await ws.receive_text()
    except WebSocketDisconnect:
        ws_monitor_manager.disconnect(ws)
    except Exception as e:
        logger.error("WS monitor error: %s", e)
        ws_monitor_manager.disconnect(ws)


@router.websocket("/ws/alerts")
async def ws_alerts(ws: WebSocket):
    await ws_alert_manager.connect(ws)
    try:
        while True:
            await ws.receive_text()
    except WebSocketDisconnect:
        ws_alert_manager.disconnect(ws)
    except Exception as e:
        logger.error("WS alerts error: %s", e)
        ws_alert_manager.disconnect(ws)
