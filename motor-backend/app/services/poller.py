"""
Poller Service
==============
Background asyncio task that:
  1. Reads VFD + PZEM every 500 ms
  2. Persists readings to SQLite via database.py
  3. Runs the alert engine
  4. Broadcasts live data to all connected WebSocket clients
"""

from __future__ import annotations

import asyncio
import logging
import time
from typing import Optional

from app.services.device_manager import DeviceManager
from app.services.alert_engine import AlertEngine
from app.db.database import save_reading
from app.ws.connection_manager import ws_monitor_manager, ws_alert_manager

logger = logging.getLogger("motor.poller")


class PollerService:
    _instance: Optional["PollerService"] = None

    def __init__(self):
        self._task: Optional[asyncio.Task] = None
        self._running = False
        self._interval = 0.75  # Base interval for sensor polling (reduced from 0.5 to lower bus load)
        self._last_ws_broadcast = 0.0
        self._ws_throttle = 0.50 # Emit to WS max 2 times per second to prevent UI lag


    @classmethod
    def get_instance(cls) -> "PollerService":
        if cls._instance is None:
            cls._instance = cls()
        return cls._instance

    async def start(self):
        if self._running:
            return
        self._running = True
        self._task = asyncio.create_task(self._loop(), name="poller")
        logger.info("Poller started (interval=%.1fs)", self._interval)

    async def stop(self):
        self._running = False
        if self._task:
            self._task.cancel()
            try:
                await self._task
            except asyncio.CancelledError:
                pass
        logger.info("Poller stopped")

    async def _loop(self):
        dm    = DeviceManager.get_instance()
        alert = AlertEngine.get_instance()

        while self._running:
            t0 = time.monotonic()
            try:
                if dm.vfd_connected or dm.pzem_connected:
                    data = await dm.read_monitor()

                    # ── Persist to DB ─────────────────────────────────────────
                    await save_reading(data)

                    # ── Alert engine ──────────────────────────────────────────
                    triggered = await alert.evaluate(data, dm.oc_threshold)
                    if triggered:
                        for a in triggered:
                            await ws_alert_manager.broadcast(a)

                        # Auto E-STOP on OC trip
                        for a in triggered:
                            if a.get("type") == "OC_TRIP" and not a.get("acknowledged"):
                                logger.warning("OC TRIP — executing E-STOP")
                                await dm.estop_motor()

                    # ── Broadcast monitor data (Throttled to fix UI lag) ──────
                    if t0 - self._last_ws_broadcast >= self._ws_throttle:
                        self._last_ws_broadcast = t0
                        payload = {**data, "alerts": triggered or []}
                        await ws_monitor_manager.broadcast(payload)

            except Exception as exc:
                logger.error("Poller error: %s", exc, exc_info=False)

            elapsed = time.monotonic() - t0
            sleep   = max(0.1, self._interval - elapsed) # enforce minimum sleep!
            await asyncio.sleep(sleep)
