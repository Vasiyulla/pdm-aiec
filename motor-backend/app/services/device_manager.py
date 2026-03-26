"""
Device Manager — singleton that owns the GD200A and PZEM-004T driver instances.
Thread-safe: all hardware calls go through asyncio.run_in_executor so they
never block the FastAPI event loop.
"""

from __future__ import annotations

import asyncio
import logging
import platform
import time
from threading import Lock
from typing import Optional

logger = logging.getLogger("motor.device_manager")

# ── Re-use the proven drivers from your original motor_control.py ─────────────
# We import them here; the original file must be on the Python path.
# If you rename it, update the import below.
try:
    import sys, os
    sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "..", "drivers"))
    from gd200a import GD200A
    from pzem004t import PZEM004T
    _DRIVERS_AVAILABLE = True
except Exception as e:
    import traceback
    traceback.print_exc()
    _DRIVERS_AVAILABLE = False
    logger.warning("Hardware drivers not found — running in SIMULATION mode.")


# ── Simulation stubs (used when real hardware is not connected) ───────────────
class _SimGD200A:
    """Generates realistic fake data for UI development / testing."""

    def __init__(self, port, **_):
        self.port = port
        self.ok = True
        self.err = ""
        self._freq = 25.0
        self._state = "STOPPED"   # STOPPED | FWD | REV
        self.err = ""

    def connect(self):
        self.ok = True
        return True

    def run_forward(self):
        self._state = "FWD"
        return True

    def run_reverse(self):
        self._state = "REV"
        return True

    def run_at_freq(self, hz: float):
        self._freq = hz
        self._state = "FWD"
        return True

    def run_reverse_at_freq(self, hz: float):
        self._freq = hz
        self._state = "REV"
        return True

    def stop(self):
        self._state = "STOPPED"
        return True

    def coast_stop(self):
        self._state = "STOPPED"
        return True

    def reset_fault(self):
        return True

    def set_frequency(self, hz: float):
        self._freq = max(0.0, min(50.0, hz))
        return True

    @staticmethod
    def rpm_to_hz(rpm: float) -> float:
        return (rpm * 4) / 120.0

    def read_monitor(self):
        import math, random
        t = time.time()
        running = self._state != "STOPPED"
        freq = self._freq if running else 0.0
        rpm  = int(freq * 30) + (random.randint(-5, 5) if running else 0)
        return {
            "set_freq":  self._freq,
            "out_freq":  freq + (random.uniform(-0.1, 0.1) if running else 0),
            "out_volt":  415.0 + random.uniform(-2, 2) if running else 0.0,
            "out_curr":  (freq / 50.0) * 3.5 + random.uniform(-0.1, 0.1) if running else 0.0,
            "motor_rpm": rpm,
            "source":    "sim",
        }

    def read_status_word(self):
        return {
            "raw":     0x0001 if self._state == "FWD" else (0x0002 if self._state == "REV" else 0x0003),
            "fwd":     self._state == "FWD",
            "rev":     self._state == "REV",
            "stopped": self._state == "STOPPED",
            "fault":   False,
        }

    def disconnect(self):
        self.ok = False


class _SimPZEM:
    """Fake PZEM-004T readings."""

    def __init__(self, port, **_):
        self.port = port
        self.ok = True

    def connect(self):
        self.ok = True
        return True

    def read_all(self):
        import random, math
        t = time.time()
        return {
            "voltage": 230.0 + math.sin(t * 0.1) * 2,
            "current": 3.2 + random.uniform(-0.2, 0.2),
            "power":   720.0 + random.uniform(-20, 20),
            "energy":  1500 + int(t / 10),
            "freq":    50.0 + random.uniform(-0.05, 0.05),
            "pf":      0.87 + random.uniform(-0.02, 0.02),
        }

    def disconnect(self):
        self.ok = False


# ── Device Manager ────────────────────────────────────────────────────────────
class DeviceManager:
    _instance: Optional["DeviceManager"] = None
    _lock = Lock()

    def __init__(self):
        self.vfd: Optional[GD200A | _SimGD200A] = None
        self.pzem: Optional[PZEM004T | _SimPZEM] = None
        self._bus_lock = asyncio.Lock()
        self._motor_state = "STOPPED"   # STOPPED | FWD | REV | FAULT
        self._oc_threshold = 10.0       # Amps
        self._simulation = not _DRIVERS_AVAILABLE

    @classmethod
    def get_instance(cls) -> "DeviceManager":
        with cls._lock:
            if cls._instance is None:
                cls._instance = cls()
            return cls._instance

    # ── Properties ────────────────────────────────────────────────────────────
    @property
    def vfd_connected(self) -> bool:
        return self.vfd is not None and self.vfd.ok

    @property
    def pzem_connected(self) -> bool:
        return self.pzem is not None and self.pzem.ok

    @property
    def motor_state(self) -> str:
        return self._motor_state

    @property
    def oc_threshold(self) -> float:
        return self._oc_threshold

    @property
    def simulation_mode(self) -> bool:
        return self._simulation

    # ── Connect / Disconnect ───────────────────────────────────────────────────
    async def connect_vfd(self, port: str, baud: int = 9600) -> dict:
        loop = asyncio.get_event_loop()
        async with self._bus_lock:
            if self.vfd and self.vfd.ok:
                self.vfd.disconnect()
            cls = GD200A if _DRIVERS_AVAILABLE else _SimGD200A
            vfd = cls(port, baud=baud)
            ok = await loop.run_in_executor(None, vfd.connect)
            if ok:
                self.vfd = vfd
                self._motor_state = "STOPPED"
                logger.info(f"VFD connected on {port}")
                return {"success": True, "port": port, "simulation": not _DRIVERS_AVAILABLE}
            return {"success": False, "error": vfd.err}

    async def connect_pzem(self, port: str, baud: int = 9600) -> dict:
        loop = asyncio.get_event_loop()
        async with self._bus_lock:
            if self.pzem and self.pzem.ok:
                self.pzem.disconnect()
            cls = PZEM004T if _DRIVERS_AVAILABLE else _SimPZEM
            pzem = cls(port, baud=baud)
            ok = await loop.run_in_executor(None, pzem.connect)
            if ok:
                self.pzem = pzem
                logger.info(f"PZEM connected on {port}")
                return {"success": True, "port": port, "simulation": not _DRIVERS_AVAILABLE}
            return {"success": False, "error": getattr(pzem, "err", "Connection failed")}

    async def disconnect_all(self):
        loop = asyncio.get_event_loop()
        if self.vfd:
            await loop.run_in_executor(None, self.vfd.disconnect)
            self.vfd = None
        if self.pzem:
            await loop.run_in_executor(None, self.pzem.disconnect)
            self.pzem = None
        self._motor_state = "STOPPED"
        logger.info("All devices disconnected")

    # ── Motor Commands ────────────────────────────────────────────────────────
    async def _vfd_cmd(self, fn, *args):
        """Run a VFD command in executor; guard against missing connection."""
        if not self.vfd_connected:
            return {"success": False, "error": "VFD not connected"}
        loop = asyncio.get_event_loop()
        async with self._bus_lock:
            ok = await loop.run_in_executor(None, lambda: fn(*args))
        return {"success": bool(ok), "error": "" if ok else self.vfd.err}

    async def run_forward(self, hz: float = None) -> dict:
        if hz is not None and hasattr(self.vfd, 'run_at_freq'):
            res = await self._vfd_cmd(self.vfd.run_at_freq, hz)
        else:
            res = await self._vfd_cmd(self.vfd.run_forward)
        if res["success"]:
            self._motor_state = "FWD"
        return res

    async def run_reverse(self, hz: float = None) -> dict:
        if hz is not None and hasattr(self.vfd, 'run_reverse_at_freq'):
            res = await self._vfd_cmd(self.vfd.run_reverse_at_freq, hz)
        else:
            res = await self._vfd_cmd(self.vfd.run_reverse)
        if res["success"]:
            self._motor_state = "REV"
        return res

    async def stop_motor(self) -> dict:
        res = await self._vfd_cmd(self.vfd.stop)
        if res["success"]:
            self._motor_state = "STOPPED"
        return res

    async def estop_motor(self) -> dict:
        res = await self._vfd_cmd(self.vfd.coast_stop)
        if res["success"]:
            self._motor_state = "STOPPED"
        return res

    async def reset_fault(self) -> dict:
        res = await self._vfd_cmd(self.vfd.reset_fault)
        if res["success"]:
            self._motor_state = "STOPPED"
        return res

    async def set_frequency(self, hz: float) -> dict:
        if not self.vfd_connected:
            return {"success": False, "error": "VFD not connected"}
        loop = asyncio.get_event_loop()
        async with self._bus_lock:
            ok = await loop.run_in_executor(
                None,
                lambda: self.vfd._wr(self.vfd.REG_FREQ_SET, int(hz * 100))
                    if hasattr(self.vfd, "REG_FREQ_SET")
                    else True   # sim mode
            )
        # For sim
        if hasattr(self.vfd, "_freq"):
            self.vfd._freq = hz
        return {"success": True, "frequency_hz": hz}

    # ── RPM conversion ─────────────────────────────────────────────────────────
    def rpm_to_hz(self, rpm: float) -> float:
        if hasattr(self.vfd, 'rpm_to_hz'):
            return self.vfd.rpm_to_hz(rpm)
        return (rpm * 4) / 120.0  # 4-pole default

    # ── Live Readings ─────────────────────────────────────────────────────────
    async def read_monitor(self) -> dict:
        loop = asyncio.get_event_loop()
        result = {"timestamp": time.time(), "motor_state": self._motor_state}

        # Perform ALL serial reads inside a single bus-lock acquisition
        # to minimise Modbus transaction overhead and prevent UI lag.
        if self.vfd_connected:
            def _read_all_vfd():
                """Runs in executor thread — does all VFD serial I/O in one go."""
                mon = self.vfd.read_monitor()
                if mon is None:
                    return None, None, (0.0, 0.0)

                # Derive power (pure calculation, no serial)
                pwr = self.vfd.read_power(mon) if hasattr(self.vfd, 'read_power') else None

                # Input voltage (1 extra Modbus read)
                inp_v = self.vfd.read_input_voltage() if hasattr(self.vfd, 'read_input_voltage') else 0.0

                # Proximity RPM (1 extra Modbus read)
                prox = self.vfd.read_hdi_freq_rpm(1) if hasattr(self.vfd, 'read_hdi_freq_rpm') else (0.0, 0.0)

                return mon, pwr, inp_v, prox

            async with self._bus_lock:
                vfd_result = await loop.run_in_executor(None, _read_all_vfd)

            if vfd_result[0] is not None:
                mon, pwr, inp_v, prox = vfd_result
                result["vfd"] = mon

                if pwr:
                    result["vfd"]["power"] = pwr["power"]
                    result["vfd"]["pf"] = pwr["pf"]
                    result["vfd"]["voltage"] = pwr["voltage"]
                    result["vfd"]["current"] = pwr["current"]

                result["vfd"]["inp_volt"] = inp_v
                result["vfd"]["prox_rpm"] = prox[0]
                result["vfd"]["prox_hz"] = prox[1]

                # Three-phase voltages = VFD output voltage (balanced)
                v = mon.get("out_volt", 0)
                result["vfd"]["phase_r"] = v
                result["vfd"]["phase_y"] = v
                result["vfd"]["phase_b"] = v
            else:
                result["vfd"] = None
                result["vfd_error"] = self.vfd.err if hasattr(self.vfd, "err") else "Read failed"

        if self.pzem_connected:
            async with self._bus_lock:
                pzem = await loop.run_in_executor(None, self.pzem.read_all)
            result["pzem"] = pzem

        return result

    # ── OC Threshold ─────────────────────────────────────────────────────────
    def set_oc_threshold(self, amps: float):
        self._oc_threshold = max(0.1, amps)
