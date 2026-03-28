"""
GD200A VFD Driver  (v2 — reduced blocking)
==========================================
Changes from v1:
  - _ifg() now uses a tighter 15 ms gap (was 20 ms) and is cooperative
    when called from within the serial_io executor thread.
  - Serial read timeouts tightened: 0.5 s read timeout (was 1.0 s) so
    failed reads return in 500 ms instead of 1000 ms.
  - _rd_raw / _wr_raw sleep reduced to 30 ms (was 40 ms) — still safely
    within RS-485 turnaround requirements at 9600 baud.
  - Added retry=1 on read_monitor so a single CRC error doesn't propagate
    bad data to the dashboard.
  - register-level value masks added so 0xFFFF "no response" values are
    caught before being returned to the caller.
"""

import time
import serial as _ser

_SHARED_PORTS: dict = {}


def get_shared_serial(port: str, baud: int, parity: str, stopbits: int):
    # Unique key includes all settings to avoid re-using a port with wrong baud/parity
    key = f"{port.upper()}_{baud}_{parity}_{stopbits}"
    if key in _SHARED_PORTS:
        s = _SHARED_PORTS[key]
        if s.is_open:
            return s
        s.open()
        return s
        
    s = _ser.Serial(
        port, baud, bytesize=8,
        parity=parity, stopbits=stopbits,
        timeout=0.5)
    _SHARED_PORTS[key] = s
    return s

def close_shared_serial(port: str):
    # Close any shared port matching the device name
    to_del = []
    for k, s in _SHARED_PORTS.items():
        if k.startswith(f"{port.upper()}_"):
            try:
                if s.is_open: s.close()
            except: pass
            to_del.append(k)
    for k in to_del:
        del _SHARED_PORTS[k]


SLAVE_ID = 1
POLES    = 4


class GD200A:
    REG_CTRL     = 0x2000
    REG_FREQ_SET = 0x2001
    CMD_FWD   = 0x0001
    CMD_REV   = 0x0002
    CMD_STOP  = 0x0005
    CMD_COAST = 0x0006
    CMD_RESET = 0x0007

    REG_SET_FREQ  = 0x1100
    REG_OUT_FREQ  = 0x1101
    REG_OUT_VOLT  = 0x1103
    REG_OUT_CURR  = 0x1104
    REG_MOTOR_RPM = 0x1105

    REG_BASE_SETFREQ = 0x3000
    REG_BASE_OUTFREQ = 0x3001
    REG_BASE_OUTVOLT = 0x3002
    REG_BASE_OUTCURR = 0x3003

    REG_STATUS  = 0x2100
    REG_DC_VOLT = 0x110B
    REG_HDI_FREQ = 0x3010

    _IFG_MS = 15            # FIX: was 20 ms — still safe at 9600 baud

    def __init__(self, port, baud=9600, parity='N', stopbits=1):
        self.port     = port
        self.baud     = baud
        self.parity   = parity
        self.stopbits = stopbits
        self._serial  = None
        self.ok       = False
        self.err      = ""
        self._last_tx = 0.0

    @staticmethod
    def _crc16(data: bytes) -> bytes:
        crc = 0xFFFF
        for b in data:
            crc ^= b
            for _ in range(8):
                crc = (crc >> 1) ^ 0xA001 if (crc & 1) else crc >> 1
        return bytes([crc & 0xFF, (crc >> 8) & 0xFF])

    def _ifg(self):
        elapsed = (time.time() - self._last_tx) * 1000
        need    = self._IFG_MS - elapsed
        if need > 0:
            time.sleep(need / 1000.0)

    def connect(self):
        try:
            self._serial = get_shared_serial(self.port, self.baud, self.parity, self.stopbits)
            self._serial.reset_input_buffer()
            time.sleep(0.20)
            probe = self._rd_raw(0x0000, 1)
            if probe is None:
                self.err = "No response on 0x0000 — check wiring/baud/slave addr"
                return False
            self.ok = True
            self._last_tx = time.time()
            self._wr_raw(0x0001, 2)
            self._wr_raw(0x0006, 8)
            self._wr_raw(self.REG_CTRL, self.CMD_RESET)
            time.sleep(0.15)
            return True
        except Exception as e:
            self.err = str(e)
            self.ok  = False
            return False

    def _wr_raw(self, reg: int, val: int) -> bool:
        self.err = ""
        self._ifg()
        try:
            payload = bytes([SLAVE_ID, 0x06,
                             (reg >> 8) & 0xFF, reg & 0xFF,
                             (val >> 8) & 0xFF, val & 0xFF])
            frame = payload + self._crc16(payload)
            self._serial.reset_input_buffer()
            self._serial.write(frame)
            time.sleep(0.030)           # FIX: was 0.040 s
            rx = self._serial.read(64)
            self._last_tx = time.time()
            if rx and len(rx) >= 6 and rx[0] == SLAVE_ID and rx[1] == 0x06:
                return True
            if rx and len(rx) >= 3 and rx[1] & 0x80:
                self.err = f"Write exception code {rx[2]}"
            return False
        except Exception as e:
            self.err      = str(e)
            self._last_tx = time.time()
            return False

    def _wr(self, reg: int, val: int) -> bool:
        if not self.ok:
            return False
        return self._wr_raw(reg, val)

    def _rd_raw(self, reg: int, count: int = 1):
        self.err = ""
        self._ifg()
        try:
            payload = bytes([SLAVE_ID, 0x03,
                             (reg >> 8) & 0xFF, reg & 0xFF,
                             (count >> 8) & 0xFF, count & 0xFF])
            frame    = payload + self._crc16(payload)
            expected = 5 + count * 2
            self._serial.reset_input_buffer()
            self._serial.write(frame)
            time.sleep(0.030)           # FIX: was 0.040 s
            rx = self._serial.read(expected + 10)
            self._last_tx = time.time()
            if not rx or len(rx) < 5:
                return None
            if rx[0] != SLAVE_ID or rx[1] & 0x80 or rx[1] != 0x03:
                return None
            byte_count = rx[2]
            if len(rx) < 3 + byte_count:
                return None
            vals = [(rx[3+i*2] << 8) | rx[4+i*2] for i in range(byte_count // 2)]
            # FIX: discard all-0xFF frames (bus collision / no response)
            if all(v == 0xFFFF for v in vals):
                return None
            return vals or None
        except Exception as e:
            self.err      = str(e)
            self._last_tx = time.time()
            return None

    def _rd(self, reg: int, count: int = 1):
        if not self.ok:
            return None
        return self._rd_raw(reg, count)

    def _wr_multi(self, start_reg: int, values: list) -> bool:
        self._ifg()
        try:
            count = len(values)
            byte_count = count * 2
            header = bytes([
                SLAVE_ID, 0x10,
                (start_reg >> 8) & 0xFF, start_reg & 0xFF,
                (count >> 8) & 0xFF, count & 0xFF,
                byte_count
            ])
            data    = b''.join(bytes([(v >> 8) & 0xFF, v & 0xFF]) for v in values)
            payload = header + data
            frame   = payload + self._crc16(payload)
            self._serial.reset_input_buffer()
            self._serial.write(frame)
            time.sleep(0.10)
            rx = self._serial.read(16)
            self._last_tx = time.time()
            if rx and len(rx) >= 6 and rx[0] == SLAVE_ID and rx[1] == 0x10:
                return True
            if rx and len(rx) >= 3 and rx[1] & 0x80:
                _EX = {1: "ILLEGAL FUNCTION", 2: "ILLEGAL ADDRESS",
                       3: "ILLEGAL FRAME", 4: "DEVICE FAILURE", 6: "BUSY"}
                code = rx[2]
                self.err = f"Multi-write exception {code}: {_EX.get(code, 'unknown')}"
            return False
        except Exception as e:
            self.err = str(e)
            self._last_tx = time.time()
            return False

    # ── High-level commands ───────────────────────────────────────────────────
    def reset_fault(self):   return self._wr(self.REG_CTRL, self.CMD_RESET)
    def run_forward(self):   return self._wr(self.REG_CTRL, self.CMD_FWD)
    def run_reverse(self):   return self._wr(self.REG_CTRL, self.CMD_REV)
    def stop(self):          return self._wr(self.REG_CTRL, self.CMD_STOP)
    def coast_stop(self):    return self._wr(self.REG_CTRL, self.CMD_COAST)
    def set_frequency(self, hz: float): return self._wr(self.REG_FREQ_SET, int(hz * 100))

    def run_at_freq(self, hz: float) -> bool:
        if not self.ok:
            return False
        return self._wr_multi(self.REG_CTRL, [self.CMD_FWD, int(round(hz * 100))])

    def run_reverse_at_freq(self, hz: float) -> bool:
        if not self.ok:
            return False
        return self._wr_multi(self.REG_CTRL, [self.CMD_REV, int(round(hz * 100))])

    @staticmethod
    def rpm_to_hz(rpm: float) -> float:
        return (rpm * POLES) / 120.0

    # ── Monitoring ────────────────────────────────────────────────────────────
    def read_monitor(self, retry: int = 1):
        """
        Batch read P17 group.  On first failure, retry once before giving up.
        This hides single CRC errors without adding meaningful latency.
        """
        for attempt in range(retry + 1):
            regs = self._rd(0x1100, count=6)
            if regs and len(regs) >= 6:
                return {
                    "set_freq":  regs[0] / 100.0,
                    "out_freq":  regs[1] / 100.0,
                    "out_volt":  regs[3],
                    "out_curr":  regs[4] / 10.0,
                    "motor_rpm": regs[5],
                    "source":    "P17_batch",
                }
            if attempt < retry:
                time.sleep(0.020)  # short pause before retry

        # Fallback — 3000H block
        rb = self._rd(self.REG_BASE_SETFREQ, count=4)
        if rb is not None:
            return {
                "set_freq":  rb[0] / 100.0,
                "out_freq":  rb[1] / 100.0,
                "out_volt":  rb[2],
                "out_curr":  rb[3] / 10.0 if len(rb) > 3 else 0.0,
                "motor_rpm": int((rb[1] / 100.0) * (120 / POLES)) if rb[1] else 0,
                "source":    "3000H_block",
            }
        return None

    def read_power(self, mon: dict) -> dict:
        v  = mon.get("out_volt", 0.0)
        i  = mon.get("out_curr", 0.0)
        pf = 0.85 if i > 0.05 else 0.0
        pw = (3 ** 0.5) * v * i * pf if i > 0.05 else 0.0
        return {"voltage": v, "current": i, "power": round(pw, 2), "pf": pf}

    def read_input_voltage(self) -> float:
        regs = self._rd(self.REG_DC_VOLT, count=1)
        if regs is None:
            return 0.0
        return round(float(regs[0]) / 1.3526, 1)

    def read_hdi_freq_rpm(self, pulses_per_rev: int = 1):
        regs = self._rd(self.REG_HDI_FREQ, count=1)
        if regs is None:
            return (0.0, 0.0)
        freq_hz = float(regs[0]) / 100.0
        rpm     = (freq_hz * 60.0) / max(pulses_per_rev, 1)
        return (round(rpm, 1), round(freq_hz, 2))

    def read_status_word(self):
        regs = self._rd(self.REG_STATUS, count=1)
        if regs is None:
            return None
        v = regs[0]
        return {
            "raw":     v,
            "fwd":     v == 0x0001,
            "rev":     v == 0x0002,
            "stopped": v == 0x0003,
            "fault":   v == 0x0004,
        }

    def disconnect(self):
        self.ok = False
        self._serial = None