"""
WebSocket Connection Manager
============================
Handles multiple simultaneous clients for both the monitor stream and the alert stream.
"""

from __future__ import annotations

import asyncio
import json
import logging
from fastapi import WebSocket

logger = logging.getLogger("motor.ws")


class ConnectionManager:
    def __init__(self, name: str):
        self.name = name
        self._clients: list[WebSocket] = []

    async def connect(self, ws: WebSocket):
        await ws.accept()
        self._clients.append(ws)
        logger.info("[%s] Client connected — total: %d", self.name, len(self._clients))

    def disconnect(self, ws: WebSocket):
        if ws in self._clients:
            self._clients.remove(ws)
        logger.info("[%s] Client disconnected — total: %d", self.name, len(self._clients))

    async def broadcast(self, data: dict):
        if not self._clients:
            return
        payload = json.dumps(data, default=str)
        dead = []
        for ws in self._clients:
            try:
                await ws.send_text(payload)
            except Exception:
                dead.append(ws)
        for ws in dead:
            self.disconnect(ws)

    @property
    def client_count(self) -> int:
        return len(self._clients)


# Singleton instances
ws_monitor_manager = ConnectionManager("monitor")
ws_alert_manager   = ConnectionManager("alerts")
