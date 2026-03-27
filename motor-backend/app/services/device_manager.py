"""
Device Manager — singleton that owns the GD200A and PZEM-004T driver instances.

FIX LOG (v2):
  - Replaced asyncio.Lock (_bus_lock) with threading.Lock for serial I/O.
    asyncio.Lock held across run_in_executor calls was stalling the entire
    event loop during 300-600 ms Modbus transactions.
  - All serial I/O now runs in a dedicated ThreadPoolExecutor (max_workers=1)
    so reads are serialised at the thread level, never at the event loop level.
  - Motor commands no longer acquire any lock; they run in the same executor
    and serialisation is guaranteed by max_workers=1.
  - read_monitor() now returns a single flat dict assembled inside the worker
    thread — zero lock contention on the asyncio side.
  - Value validation / sanity checks added so garbage reads are discarded.
"""

from __future__ import annotations

import asyncio
import logging
import time
from concurrent.futures import ThreadPoolExecutor
from threading import Lock as ThreadLock
from typing import Optional

logger = logging.getLogger("motor.device_manager")

# ── Driver imports ─────────────────────────────────────────────────────────────
try:
    import sys, os
    sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "..", "drivers"))
    from gd200a import GD200A
    from pzem004t import PZEM004T
    _DRIVERS_AVAILABLE = True
except Exception:
    _DRIVERS_AVAILABLE = False
    logger.warning("Hardware drivers not found — running in SIMULATION mode.")


# ── Simulation stubs ──────────────────────────────────────────────────────────
class _SimGD200A:
    def __init__(self, port, **_):
        self.port = port
        self.ok = True
        self.err = ""
        self._freq = 25.0
        self._state = "STOPPED"

    def connect(self): self.ok = True; return True
    def run_forward(self): self._state = "FWD"; return True
    def run_reverse(self): self._state = "REV"; return True

    def run_at_freq(self, hz: float):
        self._freq = hz; self._state = "FWD"; return True

    def run_reverse_at_freq(self, hz: float):
        self._freq = hz; self._state = "REV"; return True

    def stop(self): self._state = "STOPPED"; return True
    def coast_stop(self): self._state = "STOPPED"; return True
    def reset_fault(self): return True

    def set_frequency(self, hz: float):
        self._freq = max(0.0, min(50.0, hz)); return True

    @staticmethod
    def rpm_to_hz(rpm: float) -> float: return (rpm * 4) / 120.0

    def read_monitor(self):
        import random
        running = self._state != "STOPPED"
        freq = self._freq if running else 0.0
        rpm  = int(freq * 30) + (random.randint(-3, 3) if running else 0)
        volt = 415.0 + random.uniform(-1, 1) if running else 0.0
        curr = (freq / 50.0) * 3.5 + random.uniform(-0.05, 0.05) if running else 0.0
        return {
            "set_freq":  self._freq,
            "out_freq":  round(freq + (random.uniform(-0.05, 0.05) if running else 0), 2),
            "out_volt":  round(volt, 1),
            "out_curr":  round(curr, 2),
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

    # Sim stubs for optional methods
    def read_power(self, mon):
        v = mon.get("out_volt", 0.0)
        i = mon.get("out_curr", 0.0)
        pf = 0.85 if i > 0.05 else 0.0
        pw = (3 ** 0.5) * v * i * pf if i > 0.05 else 0.0
        return {"voltage": v, "current": i, "power": round(pw, 1), "pf": pf}

    def read_input_voltage(self):
        import random
        return round(415.0 + random.uniform(-2, 2), 1)

    def read_hdi_freq_rpm(self, pulses_per_rev=1):
        import random
        hz = (self._freq + random.uniform(-0.1, 0.1)) if self._state != "STOPPED" else 0.0
        rpm = (hz * 60.0) / max(pulses_per_rev, 1)
        return (round(rpm, 1), round(hz, 2))

    def disconnect(self): self.ok = False

    # Expose register attr so set_frequency path works
    REG_FREQ_SET = 0x2001

    def _wr(self, reg, val):
        if reg == self.REG_FREQ_SET:
            self._freq = val / 100.0
        return True


class _SimPZEM:
    def __init__(self, port, **_):
        self.port = port
        self.ok = True

    def connect(self): self.ok = True; return True

    def read_all(self):
        import random, math
        t = time.time()
        return {
            "voltage": round(230.0 + math.sin(t * 0.1) * 1.5, 1),
            "current": round(3.2 + random.uniform(-0.1, 0.1), 2),
            "power":   round(720.0 + random.uniform(-10, 10), 1),
            "energy":  1500 + int(t / 10),
            "freq":    round(50.0 + random.uniform(-0.02, 0.02), 2),
            "pf":      round(0.87 + random.uniform(-0.01, 0.01), 2),
        }

    def disconnect(self): self.ok = False


# ── Value sanity checks ───────────────────────────────────────────────────────
# Discard obviously wrong readings from noisy RS-485 lines.
_VFD_LIMITS = {
    "out_freq":  (0.0, 55.0),      # Hz
    "out_volt":  (0.0, 500.0),     # V
    "out_curr":  (0.0, 50.0),      # A
    "motor_rpm": (0, 3100),        # RPM (4-pole, 50 Hz sync = 1500 rpm + slip)
    "set_freq":  (0.0, 55.0),
}

def _validate_vfd(mon: dict) -> dict:
    """Return mon with out-of-range values replaced by None (caller handles)."""
    cleaned = dict(mon)
    for key, (lo, hi) in _VFD_LIMITS.items():
        v = cleaned.get(key)
        if v is not None and not (lo <= v <= hi):
            logger.warning("VFD sanity: %s=%s out of range [%s, %s] — discarded", key, v, lo, hi)
            cleaned[key] = None
    return cleaned


# ── Device Manager ────────────────────────────────────────────────────────────
class DeviceManager:
    """
    All serial I/O runs on a single-worker ThreadPoolExecutor.
    max_workers=1 guarantees serial transactions never overlap
    without ever blocking the asyncio event loop.
    """
    _instance: Optional["DeviceManager"] = None
    _class_lock = ThreadLock()

    def __init__(self):
        self.vfd = None
        self.pzem = None
        # ── KEY FIX: single-worker executor for all serial I/O ──────────────
        self._executor = ThreadPoolExecutor(max_workers=1, thread_name_prefix="serial_io")
        self._motor_state = "STOPPED"
        self._oc_threshold = 10.0
        self._simulation = not _DRIVERS_AVAILABLE

    @classmethod
    def get_instance(cls) -> "DeviceManager":
        with cls._class_lock:
            if cls._instance is None:
                cls._instance = cls()
            return cls._instance

    # ── Helpers ───────────────────────────────────────────────────────────────
    async def _run(self, fn, *args):
        """Submit a blocking call to the serial executor without stalling the event loop."""
        loop = asyncio.get_event_loop()
        return await loop.run_in_executor(self._executor, fn, *args)

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

    # ── Connect / Disconnect ──────────────────────────────────────────────────
    async def connect_vfd(self, port: str, baud: int = 9600) -> dict:
        cls = GD200A if _DRIVERS_AVAILABLE else _SimGD200A
        vfd = cls(port, baud=baud)
        ok = await self._run(vfd.connect)
        if ok:
            self.vfd = vfd
            self._motor_state = "STOPPED"
            logger.info("VFD connected on %s", port)
            return {"success": True, "port": port, "simulation": not _DRIVERS_AVAILABLE}
        return {"success": False, "error": getattr(vfd, "err", "Connection failed")}

    async def connect_pzem(self, port: str, baud: int = 9600) -> dict:
        cls = PZEM004T if _DRIVERS_AVAILABLE else _SimPZEM
        pzem = cls(port, baud=baud)
        ok = await self._run(pzem.connect)
        if ok:
            self.pzem = pzem
            logger.info("PZEM connected on %s", port)
            return {"success": True, "port": port, "simulation": not _DRIVERS_AVAILABLE}
        return {"success": False, "error": getattr(pzem, "err", "Connection failed")}

    async def disconnect_all(self):
        if self.vfd:
            await self._run(self.vfd.disconnect)
            self.vfd = None
        if self.pzem:
            await self._run(self.pzem.disconnect)
            self.pzem = None
        self._motor_state = "STOPPED"
        logger.info("All devices disconnected")

    # ── Motor Commands ────────────────────────────────────────────────────────
    async def run_forward(self, hz: float = None) -> dict:
        if not self.vfd_connected:
            return {"success": False, "error": "VFD not connected"}
        if hz is not None and hasattr(self.vfd, "run_at_freq"):
            ok = await self._run(self.vfd.run_at_freq, hz)
        else:
            ok = await self._run(self.vfd.run_forward)
        if ok:
            self._motor_state = "FWD"
        return {"success": bool(ok), "error": "" if ok else getattr(self.vfd, "err", "")}

    async def run_reverse(self, hz: float = None) -> dict:
        if not self.vfd_connected:
            return {"success": False, "error": "VFD not connected"}
        if hz is not None and hasattr(self.vfd, "run_reverse_at_freq"):
            ok = await self._run(self.vfd.run_reverse_at_freq, hz)
        else:
            ok = await self._run(self.vfd.run_reverse)
        if ok:
            self._motor_state = "REV"
        return {"success": bool(ok), "error": "" if ok else getattr(self.vfd, "err", "")}

    async def stop_motor(self) -> dict:
        if not self.vfd_connected:
            return {"success": False, "error": "VFD not connected"}
        ok = await self._run(self.vfd.stop)
        if ok:
            self._motor_state = "STOPPED"
        return {"success": bool(ok), "error": "" if ok else getattr(self.vfd, "err", "")}

    async def estop_motor(self) -> dict:
        if not self.vfd_connected:
            return {"success": False, "error": "VFD not connected"}
        ok = await self._run(self.vfd.coast_stop)
        if ok:
            self._motor_state = "STOPPED"
        return {"success": bool(ok)}

    async def reset_fault(self) -> dict:
        if not self.vfd_connected:
            return {"success": False, "error": "VFD not connected"}
        ok = await self._run(self.vfd.reset_fault)
        if ok:
            self._motor_state = "STOPPED"
        return {"success": bool(ok)}

    async def set_frequency(self, hz: float) -> dict:
        if not self.vfd_connected:
            return {"success": False, "error": "VFD not connected"}

        def _do_set():
            if hasattr(self.vfd, "REG_FREQ_SET"):
                return self.vfd._wr(self.vfd.REG_FREQ_SET, int(hz * 100))
            return True

        ok = await self._run(_do_set)
        if hasattr(self.vfd, "_freq"):   # keep sim in sync
            self.vfd._freq = hz
        return {"success": bool(ok), "frequency_hz": hz}

    # ── RPM helper ────────────────────────────────────────────────────────────
    def rpm_to_hz(self, rpm: float) -> float:
        if hasattr(self.vfd, "rpm_to_hz"):
            return self.vfd.rpm_to_hz(rpm)
        return (rpm * 4) / 120.0

    # ── Live Readings ─────────────────────────────────────────────────────────
    async def read_monitor(self) -> dict:
        """
        All serial reads happen in one executor task — they are naturally
        serialised by the single-worker pool.  The event loop is never blocked.
        """
        result = {"timestamp": time.time(), "motor_state": self._motor_state}

        vfd_connected  = self.vfd_connected
        pzem_connected = self.pzem_connected

        def _read_all() -> dict:
            """This runs in the serial_io thread — may take 200-500 ms, that's OK."""
            out = {}

            if vfd_connected:
                try:
                    mon = self.vfd.read_monitor()
                    if mon is not None:
                        mon = _validate_vfd(mon)

                        if hasattr(self.vfd, "read_power"):
                            pwr = self.vfd.read_power(mon)
                            mon["power"]   = round(pwr.get("power", 0.0), 1)
                            mon["pf"]      = round(pwr.get("pf", 0.0), 2)
                            mon["voltage"] = pwr.get("voltage")
                            mon["current"] = pwr.get("current")

                        if hasattr(self.vfd, "read_input_voltage"):
                            mon["inp_volt"] = self.vfd.read_input_voltage()

                        if hasattr(self.vfd, "read_hdi_freq_rpm"):
                            prox = self.vfd.read_hdi_freq_rpm(1)
                            mon["prox_rpm"] = prox[0]
                            mon["prox_hz"]  = prox[1]

                        v = mon.get("out_volt", 0)
                        mon["phase_r"] = v
                        mon["phase_y"] = v
                        mon["phase_b"] = v
                        out["vfd"] = mon
                    else:
                        out["vfd"] = None
                        out["vfd_error"] = getattr(self.vfd, "err", "Read failed")
                except Exception as exc:
                    logger.error("VFD read error: %s", exc)
                    out["vfd"] = None
                    out["vfd_error"] = str(exc)

            if pzem_connected:
                try:
                    pzem_data = self.pzem.read_all()
                    out["pzem"] = pzem_data
                except Exception as exc:
                    logger.error("PZEM read error: %s", exc)
                    out["pzem"] = None

            return out

        if vfd_connected or pzem_connected:
            readings = await self._run(_read_all)
            result.update(readings)

        return result

    # ── OC Threshold ─────────────────────────────────────────────────────────
    def set_oc_threshold(self, amps: float):
        self._oc_threshold = max(0.1, amps)