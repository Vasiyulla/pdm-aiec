"""
Poller Service  (v2 — lag-free)
================================
Changes from v1:
  - Poll interval raised to 1.5 s (was 0.75 s).
    A 4-pole induction motor changes state slowly; 1.5 s is fine for
    dashboards and well within PdM response-time requirements.
  - WebSocket throttle raised to 1.0 s (was 0.50 s).
    Flutter/Dart rebuilds the widget tree on every message; flooding it
    at 2 Hz was causing frame drops and apparent mouse freeze.
  - Serial reads and WS broadcasts are now fully decoupled:
    readings happen in the serial_io executor thread;
    broadcasts happen in the asyncio loop after the executor returns.
  - Alert evaluation is a lightweight pure-Python check — no I/O —
    so it runs directly in the loop.
  - Added a _consecutive_errors counter; if hardware fails 5× in a row
    the poller backs off to 5 s to avoid log spam.
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

# ── Tunable constants ─────────────────────────────────────────────────────────
_POLL_INTERVAL   = 1.5   # seconds between hardware reads
_WS_THROTTLE     = 1.0   # minimum seconds between WebSocket broadcasts
_BACKOFF_ERRORS  = 5     # consecutive failures before backing off
_BACKOFF_INTERVAL = 5.0  # seconds to sleep during backoff


class PollerService:
    _instance: Optional["PollerService"] = None

    def __init__(self):
        self._task: Optional[asyncio.Task] = None
        self._running = False
        self._last_ws_broadcast = 0.0
        self._consecutive_errors = 0

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
        logger.info("Poller started (interval=%.1fs, ws_throttle=%.1fs)",
                    _POLL_INTERVAL, _WS_THROTTLE)

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
            interval = _POLL_INTERVAL

            try:
                if dm.vfd_connected or dm.pzem_connected:
                    # ── 1. Read hardware (runs in serial_io executor — non-blocking) ──
                    data = await dm.read_monitor()

                    # ── 2. Persist (async DB write) ───────────────────────────
                    await save_reading(data)

                    # ── 3. Alert evaluation (pure Python, in event loop) ──────
                    triggered = await alert.evaluate(data, dm.oc_threshold)

                    if triggered:
                        for a in triggered:
                            await ws_alert_manager.broadcast(a)

                        # Auto E-STOP on OC trip (non-blocking — uses executor)
                        for a in triggered:
                            if a.get("type") == "OC_TRIP" and not a.get("acknowledged"):
                                logger.warning("OC TRIP — executing E-STOP")
                                asyncio.create_task(dm.estop_motor())

                    # ── 4. Throttled WebSocket broadcast ──────────────────────
                    now = time.monotonic()
                    if now - self._last_ws_broadcast >= _WS_THROTTLE:
                        self._last_ws_broadcast = now
                        payload = {**data, "alerts": triggered or []}
                        # fire-and-forget — do NOT await so broadcast never
                        # delays the next poll cycle
                        asyncio.create_task(
                            ws_monitor_manager.broadcast(payload),
                            name="ws_broadcast"
                        )

                    self._consecutive_errors = 0   # reset on success

            except asyncio.CancelledError:
                raise
            except Exception as exc:
                self._consecutive_errors += 1
                logger.error("Poller error (#%d): %s",
                             self._consecutive_errors, exc, exc_info=False)
                if self._consecutive_errors >= _BACKOFF_ERRORS:
                    logger.warning("Too many errors — backing off to %.0fs", _BACKOFF_INTERVAL)
                    interval = _BACKOFF_INTERVAL

            elapsed = time.monotonic() - t0
            sleep   = max(0.05, interval - elapsed)
            await asyncio.sleep(sleep)