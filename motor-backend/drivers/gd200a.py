"""
GD200A VFD Driver
=================
Pure-pyserial Modbus RTU driver for INVT GD200A frequency inverter.
Extracted from motor_control.py — original hardware-confirmed register map.

Usage:
    from gd200a import GD200A
    vfd = GD200A("COM7")
    vfd.connect()
    vfd.set_frequency(25.0)
    vfd.run_forward()
    data = vfd.read_monitor()
    vfd.stop()
    vfd.disconnect()
"""

import time
import platform
import serial as _ser

# Global serial port registry to share ports across devices
_SHARED_PORTS = {}

def get_shared_serial(port: str, baud: int, parity: str, stopbits: int):
    # If the port is already open, increase ref count and return it
    key = port.upper()
    if key in _SHARED_PORTS:
        return _SHARED_PORTS[key]
    
    s = _ser.Serial(
        port, baud, bytesize=8,
        parity=parity, stopbits=stopbits,
        timeout=1.0)
    _SHARED_PORTS[key] = s
    return s

SLAVE_ID = 1      # must match P14.00 in VFD parameters
POLES    = 4      # motor poles (used for synchronous RPM calc if needed)


class GD200A:
    # ── Control registers ─────────────────────────────────────────────────────
    REG_CTRL     = 0x2000
    REG_FREQ_SET = 0x2001

    # ── Control word values ───────────────────────────────────────────────────
    CMD_FWD   = 0x0001
    CMD_REV   = 0x0002
    CMD_STOP  = 0x0005
    CMD_COAST = 0x0006
    CMD_RESET = 0x0007

    # ── P17 Monitoring registers (only valid while RUNNING) ───────────────────
    REG_SET_FREQ  = 0x1100
    REG_OUT_FREQ  = 0x1101
    REG_OUT_VOLT  = 0x1103
    REG_OUT_CURR  = 0x1104
    REG_MOTOR_RPM = 0x1105

    # ── Base block (always readable) ──────────────────────────────────────────
    REG_BASE_SETFREQ = 0x3000
    REG_BASE_OUTFREQ = 0x3001
    REG_BASE_OUTVOLT = 0x3002
    REG_BASE_OUTCURR = 0x3003
    REG_BASE_PROBE   = 0x3000

    # ── Status / DC bus ───────────────────────────────────────────────────────
    REG_STATUS  = 0x2100
    REG_DC_VOLT = 0x110B

    _IFG_MS = 20   # inter-frame gap (ms) — this firmware requires it

    def __init__(self, port, baud=9600, parity='N', stopbits=1):
        self.port     = port
        self.baud     = baud
        self.parity   = parity
        self.stopbits = stopbits
        self._serial  = None
        self.ok       = False
        self.err      = ""
        self._last_tx = 0.0

    # ── CRC ──────────────────────────────────────────────────────────────────
    @staticmethod
    def _crc16(data: bytes) -> bytes:
        crc = 0xFFFF
        for b in data:
            crc ^= b
            for _ in range(8):
                crc = (crc >> 1) ^ 0xA001 if (crc & 1) else crc >> 1
        return bytes([crc & 0xFF, (crc >> 8) & 0xFF])

    # ── Inter-frame gap ───────────────────────────────────────────────────────
    def _ifg(self):
        elapsed = (time.time() - self._last_tx) * 1000
        need    = self._IFG_MS - elapsed
        if need > 0:
            time.sleep(need / 1000.0)

    # ── Raw serial connect ────────────────────────────────────────────────────
    def connect(self):
        try:
            self._serial = get_shared_serial(self.port, self.baud, self.parity, self.stopbits)
            self._serial.reset_input_buffer()
            time.sleep(0.20)   # mandatory 200 ms warmup
            probe = self._rd_raw(0x0000, 1)
            if probe is None:
                self.err = "No response on 0x0000 — check wiring/baud/slave addr"
                self._serial.close()
                return False
            self.ok = True
            self._last_tx = time.time()
            
            # Force VFD into modbus control (P00.01 = 2) and modbus frequency (P00.06 = 8)
            self._wr_raw(0x0001, 2)
            self._wr_raw(0x0006, 8)
            
            self._wr_raw(self.REG_CTRL, self.CMD_RESET)  # clear any CE fault on startup
            time.sleep(0.15)
            return True
        except Exception as e:
            self.err = str(e)
            self.ok  = False
            return False

    # ── Low-level read / write ────────────────────────────────────────────────
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
            time.sleep(0.04)  # Reduced from 0.08
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
            time.sleep(0.04)  # Reduced from 0.08
            rx = self._serial.read(expected + 10)
            self._last_tx = time.time()
            if not rx or len(rx) < 5:
                return None
            if rx[0] != SLAVE_ID or rx[1] & 0x80 or rx[1] != 0x03:
                return None
            byte_count = rx[2]
            if len(rx) < 3 + byte_count:
                return None
            return [(rx[3+i*2] << 8) | rx[4+i*2] for i in range(byte_count // 2)] or None
        except Exception as e:
            self.err      = str(e)
            self._last_tx = time.time()
            return None

    def _rd(self, reg: int, count: int = 1):
        if not self.ok:
            return None
        return self._rd_raw(reg, count)

    # ── Multi-register write (func 10H) ─────────────────────────────────────
    def _wr_multi(self, start_reg: int, values: list) -> bool:
        """Modbus func 10H — write multiple consecutive registers in one frame.

        Per GD200A manual section 9.4.8.3: this is the correct way to send
        RUN command + frequency setpoint atomically (avoids exception code 03H
        that occurs when two separate func-06H frames are sent back-to-back).
        """
        self._ifg()
        try:
            count = len(values)
            byte_count = count * 2
            header = bytes([
                SLAVE_ID, 0x10,
                (start_reg >> 8) & 0xFF, start_reg & 0xFF,
                (count >> 8) & 0xFF,     count & 0xFF,
                byte_count
            ])
            data = b''.join(
                bytes([(v >> 8) & 0xFF, v & 0xFF]) for v in values
            )
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
                       3: "ILLEGAL FRAME (bad CRC/length)",
                       4: "DEVICE FAILURE", 6: "BUSY"}
                code = rx[2]
                self.err = f"Multi-write exception {code}: {_EX.get(code, 'unknown')}"
            return False
        except Exception as e:
            self.err = str(e)
            self._last_tx = time.time()
            return False

    # ── High-level commands ───────────────────────────────────────────────────
    def reset_fault(self):
        return self._wr(self.REG_CTRL, self.CMD_RESET)

    def run_forward(self):
        return self._wr(self.REG_CTRL, self.CMD_FWD)

    def run_reverse(self):
        return self._wr(self.REG_CTRL, self.CMD_REV)

    def run_at_freq(self, hz: float) -> bool:
        """Send RUN FORWARD + frequency setpoint in a single func-10H frame.

        This is the method shown in GD200A manual section 9.4.8.3 example 1.
        Avoids exception 03H caused by two rapid func-06H frames.
        """
        if not self.ok:
            return False
        freq_val = int(round(hz * 100))
        return self._wr_multi(self.REG_CTRL, [self.CMD_FWD, freq_val])

    def run_reverse_at_freq(self, hz: float) -> bool:
        """Send RUN REVERSE + frequency setpoint in a single func-10H frame."""
        if not self.ok:
            return False
        freq_val = int(round(hz * 100))
        return self._wr_multi(self.REG_CTRL, [self.CMD_REV, freq_val])

    def stop(self):
        return self._wr(self.REG_CTRL, self.CMD_STOP)

    def coast_stop(self):
        return self._wr(self.REG_CTRL, self.CMD_COAST)

    def set_frequency(self, hz: float) -> bool:
        return self._wr(self.REG_FREQ_SET, int(hz * 100))

    @staticmethod
    def rpm_to_hz(rpm: float) -> float:
        return (rpm * POLES) / 120.0

    # ── Monitoring ────────────────────────────────────────────────────────────
    def read_monitor(self):
        """Batch read P17 group (0x1100-0x1105) for high-speed performance."""
        # This reduces 2 Modbus transactions to 1.
        # Regs: 1100 (Set Freq), 1101 (Out Freq), 1102 (Reserved), 1103 (Out Volt), 1104 (Out Curr), 1105 (RPM)
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
        
        # Fallback — 3000H block (Standard INVT status block)
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
        """Derive power metrics from monitor dict.

        Power = sqrt(3) x V x I x PF  (3-phase).
        PF assumed 0.85 for loaded induction motor, 0.0 when stopped.
        """
        v  = mon.get("out_volt", 0.0)
        i  = mon.get("out_curr", 0.0)
        pf = 0.85 if i > 0.05 else 0.0
        pw = (3 ** 0.5) * v * i * pf if i > 0.05 else 0.0
        return {"voltage": v, "current": i, "power": pw, "pf": pf}

    def read_input_voltage(self) -> float:
        """Read AC input (supply) voltage via DC bus register 0x110B.
        
        Using 1.3526 calibration factor for increased accuracy on 3-phase rectifiers.
        """
        regs = self._rd(self.REG_DC_VOLT, count=1)
        if regs is None:
            return 0.0
        v_dc = float(regs[0])
        return round(v_dc / 1.3526, 1)

    REG_HDI_FREQ = 0x3010

    def read_hdi_freq_rpm(self, pulses_per_rev: int = 1):
        """Read shaft RPM from HDI hardware frequency counter (register 0x3010).

        Unit = 0.01 Hz per count.
        Returns (rpm, freq_hz) or (0.0, 0.0) on failure.
        """
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
