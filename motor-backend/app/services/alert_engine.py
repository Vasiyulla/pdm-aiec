"""
Alert Engine
============
Evaluates every poll cycle against configurable thresholds.

Alert types:
  OC_WARNING   — current > threshold * 0.85
  OC_TRIP      — current > threshold for > 1 s  → triggers E-STOP
  OVERVOLTAGE  — voltage > 265 V
  UNDERVOLTAGE — voltage < 195 V
  OVERFREQ     — output freq > 51 Hz
  LOW_PF       — power factor < 0.70
  VFD_COMMS    — VFD read returned None while motor should be running
"""

from __future__ import annotations

import asyncio
import time
import uuid
import logging
from typing import Optional

logger = logging.getLogger("motor.alerts")

# Active (unacknowledged) alerts keyed by type; prevents flooding.
_ACTIVE: dict[str, dict] = {}
# All recent alerts for GET /api/alerts
_HISTORY: list[dict] = []
_MAX_HISTORY = 200


def _new_alert(alert_type: str, message: str, severity: str, data: dict) -> dict:
    a = {
        "id":           str(uuid.uuid4()),
        "type":         alert_type,
        "message":      message,
        "severity":     severity,   # INFO | WARNING | CRITICAL
        "timestamp":    time.time(),
        "acknowledged": False,
        "data":         data,
    }
    return a


class AlertEngine:
    _instance: Optional["AlertEngine"] = None

    def __init__(self):
        self._oc_start: Optional[float] = None   # timestamp when OC first seen
        self._oc_trip_delay = 1.0                # seconds before trip

    @classmethod
    def get_instance(cls) -> "AlertEngine":
        if cls._instance is None:
            cls._instance = cls()
        return cls._instance

    async def evaluate(self, data: dict, oc_threshold: float) -> list[dict]:
        """Return list of new alerts generated this cycle."""
        new_alerts = []

        pzem = data.get("pzem") or {}
        vfd  = data.get("vfd")  or {}
        state = data.get("motor_state", "STOPPED")

        current = pzem.get("current", 0.0)
        voltage = pzem.get("voltage", 0.0)
        pf      = pzem.get("pf", 1.0)
        out_freq = vfd.get("out_freq", 0.0)

        # ── Overcurrent ───────────────────────────────────────────────────────
        if current > oc_threshold and "OC_TRIP" not in _ACTIVE:
            if self._oc_start is None:
                self._oc_start = time.time()

            if (time.time() - self._oc_start) >= self._oc_trip_delay:
                a = _new_alert(
                    "OC_TRIP",
                    f"Overcurrent TRIP: {current:.2f} A exceeds {oc_threshold:.2f} A threshold",
                    "CRITICAL",
                    {"current": current, "threshold": oc_threshold},
                )
                _ACTIVE["OC_TRIP"] = a
                _push_history(a)
                new_alerts.append(a)
                logger.critical("OC TRIP: %.2f A", current)

            elif (time.time() - self._oc_start) >= 0.2 and "OC_WARNING" not in _ACTIVE:
                a = _new_alert(
                    "OC_WARNING",
                    f"Overcurrent WARNING: {current:.2f} A (threshold {oc_threshold:.2f} A)",
                    "WARNING",
                    {"current": current, "threshold": oc_threshold},
                )
                _ACTIVE["OC_WARNING"] = a
                _push_history(a)
                new_alerts.append(a)

        elif current <= oc_threshold:
            self._oc_start = None
            _ACTIVE.pop("OC_WARNING", None)
            _ACTIVE.pop("OC_TRIP", None)

        # ── Overvoltage ───────────────────────────────────────────────────────
        if voltage > 265 and "OVERVOLTAGE" not in _ACTIVE:
            a = _new_alert("OVERVOLTAGE",
                           f"Overvoltage: {voltage:.1f} V", "CRITICAL",
                           {"voltage": voltage})
            _ACTIVE["OVERVOLTAGE"] = a
            _push_history(a)
            new_alerts.append(a)
        elif voltage <= 265:
            _ACTIVE.pop("OVERVOLTAGE", None)

        # ── Undervoltage ──────────────────────────────────────────────────────
        if 0 < voltage < 195 and "UNDERVOLTAGE" not in _ACTIVE:
            a = _new_alert("UNDERVOLTAGE",
                           f"Undervoltage: {voltage:.1f} V", "WARNING",
                           {"voltage": voltage})
            _ACTIVE["UNDERVOLTAGE"] = a
            _push_history(a)
            new_alerts.append(a)
        elif voltage == 0 or voltage >= 195:
            _ACTIVE.pop("UNDERVOLTAGE", None)

        # ── Over-frequency ────────────────────────────────────────────────────
        if out_freq > 51.0 and "OVERFREQ" not in _ACTIVE:
            a = _new_alert("OVERFREQ",
                           f"Over-frequency: {out_freq:.2f} Hz", "WARNING",
                           {"out_freq": out_freq})
            _ACTIVE["OVERFREQ"] = a
            _push_history(a)
            new_alerts.append(a)
        elif out_freq <= 51.0:
            _ACTIVE.pop("OVERFREQ", None)

        # ── Low Power Factor ──────────────────────────────────────────────────
        if 0 < pf < 0.70 and "LOW_PF" not in _ACTIVE:
            a = _new_alert("LOW_PF",
                           f"Low power factor: {pf:.2f}", "INFO",
                           {"pf": pf})
            _ACTIVE["LOW_PF"] = a
            _push_history(a)
            new_alerts.append(a)
        elif pf >= 0.70 or pf == 0:
            _ACTIVE.pop("LOW_PF", None)

        # ── VFD comms loss ────────────────────────────────────────────────────
        if state != "STOPPED" and vfd is None and "VFD_COMMS" not in _ACTIVE:
            a = _new_alert("VFD_COMMS",
                           "VFD communication lost while motor running", "CRITICAL",
                           {})
            _ACTIVE["VFD_COMMS"] = a
            _push_history(a)
            new_alerts.append(a)
        elif vfd is not None:
            _ACTIVE.pop("VFD_COMMS", None)

        return new_alerts

    # ── Public helpers ─────────────────────────────────────────────────────────
    @staticmethod
    def get_active() -> list[dict]:
        return list(_ACTIVE.values())

    @staticmethod
    def get_history(limit: int = 50) -> list[dict]:
        return _HISTORY[-limit:]

    @staticmethod
    def acknowledge(alert_id: str) -> bool:
        for a in _ACTIVE.values():
            if a["id"] == alert_id:
                a["acknowledged"] = True
                return True
        for a in _HISTORY:
            if a["id"] == alert_id:
                a["acknowledged"] = True
                return True
        return False


def _push_history(alert: dict):
    _HISTORY.append(alert)
    if len(_HISTORY) > _MAX_HISTORY:
        _HISTORY.pop(0)
