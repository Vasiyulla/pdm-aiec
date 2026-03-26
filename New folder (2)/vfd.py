"""
Driver for INVT GD200A VFD — pure pyserial, no pymodbus dependency.

Confirmed register map (COM7, 9600/N81, slave=1):

BASE BLOCK  0x0000-0x0005  — always readable (func 03H), stopped OR running:
  0x0000  Setting frequency   (÷100 → Hz)
  0x0001  Output frequency    (÷100 → Hz)
  0x0002  Output voltage      (V direct)

P17 GROUP   0x1100-0x1105   — only valid while motor is RUNNING (exception 6 when stopped):
  0x1100  P17.00  Setting frequency  (÷100 → Hz)
  0x1101  P17.01  Output frequency   (÷100 → Hz)
  0x1103  P17.03  Output voltage     (V)
  0x1104  P17.04  Output current     (÷10 → A)
  0x1105  P17.05  Motor speed        (RPM)

CONTROL REGISTERS  (func 06H write, always accepted):
  0x2000  Control word  (RESET=0x0007, FWD=0x0001, REV=0x0002, STOP=0x0005)
  0x2001  Freq setpoint (÷100, e.g. 25 Hz = 2500)

KEY FINDING: pymodbus opens the COM port and immediately sends a frame with
no inter-frame gap. This GD200A firmware requires >= 150 ms after port-open
before accepting any Modbus frame. Pure pyserial bypasses this completely.
"""

import time

SLAVE_ID = 1      # must match VFD parameter P14.00
POLES    = 4      # motor poles


class GD200A:
    """INVT GD200A Modbus RTU driver -- pure pyserial, no pymodbus."""

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

    REG_BASE_SETFREQ = 0x0000
    REG_BASE_OUTFREQ = 0x0001
    REG_BASE_OUTVOLT = 0x0002
    REG_BASE_PROBE   = 0x0000

    REG_STATUS   = 0x2100
    REG_DC_VOLT  = 0x110B
    REG_HDI_FREQ = 0x3010

    _IFG_MS = 60

    def __init__(self, port, baud=9600, parity='N', stopbits=1):
        self.port      = port
        self.baud      = baud
        self.parity    = parity
        self.stopbits  = stopbits
        self._serial   = None
        self.ok        = False
        self.err       = ""
        self._last_tx  = 0.0

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
        need = self._IFG_MS - elapsed
        if need > 0:
            time.sleep(need / 1000.0)

    def connect(self):
        """Open serial port and confirm device responds on register 0x0000."""
        try:
            import serial as _ser
            self._serial = _ser.Serial(
                self.port, self.baud, bytesize=8,
                parity=self.parity, stopbits=self.stopbits,
                timeout=1.0)
            self._serial.reset_input_buffer()
            time.sleep(0.20)   # mandatory warmup
            probe = self._rd_raw(0x0000, 1)
            if probe is None:
                self.err = "No response on 0x0000 -- check wiring/baud/slave addr"
                self._serial.close()
                return False
            self.ok = True
            self._last_tx = time.time()
            self._wr_raw(self.REG_CTRL, self.CMD_RESET)
            time.sleep(0.15)
            return True
        except Exception as e:
            self.err = str(e)
            self.ok = False
            return False

    def _wr_raw(self, reg: int, val: int) -> bool:
        self._ifg()
        try:
            payload = bytes([SLAVE_ID, 0x06,
                             (reg >> 8) & 0xFF, reg & 0xFF,
                             (val >> 8) & 0xFF, val & 0xFF])
            frame = payload + self._crc16(payload)
            self._serial.reset_input_buffer()
            self._serial.write(frame)
            time.sleep(0.08)
            rx = self._serial.read(64)
            self._last_tx = time.time()
            if rx and len(rx) >= 6 and rx[0] == SLAVE_ID and rx[1] == 0x06:
                return True
            if rx and len(rx) >= 3 and rx[1] & 0x80:
                self.err = f"Write exception code {rx[2]}"
            return False
        except Exception as e:
            self.err = str(e)
            self._last_tx = time.time()
            return False

    def _wr(self, reg: int, val: int) -> bool:
        if not self.ok:
            return False
        return self._wr_raw(reg, val)

    def _rd_raw(self, reg: int, count: int = 1):
        self._ifg()
        try:
            payload = bytes([SLAVE_ID, 0x03,
                             (reg >> 8) & 0xFF, reg & 0xFF,
                             (count >> 8) & 0xFF, count & 0xFF])
            frame = payload + self._crc16(payload)
            self._serial.reset_input_buffer()
            self._serial.write(frame)
            expected = 5 + count * 2
            time.sleep(0.08)
            rx = self._serial.read(expected + 4)
            self._last_tx = time.time()
            if not rx or len(rx) < 5:
                return None
            if rx[0] != SLAVE_ID:
                return None
            if rx[1] & 0x80:
                return None   # exception 6 = busy when stopped -- normal
            if rx[1] != 0x03:
                return None
            byte_count = rx[2]
            if len(rx) < 3 + byte_count:
                return None
            regs = []
            for i in range(byte_count // 2):
                regs.append((rx[3 + i*2] << 8) | rx[4 + i*2])
            return regs if regs else None
        except Exception as e:
            self.err = str(e)
            self._last_tx = time.time()
            return None

    def _rd(self, reg: int, count: int = 1):
        if not self.ok:
            return None
        return self._rd_raw(reg, count)

    def reset_fault(self):
        return self._wr(self.REG_CTRL, self.CMD_RESET)

    def _wr_multi(self, start_reg: int, values: list) -> bool:
        """Modbus func 10H — write multiple consecutive registers in one frame.

        Per GD200A manual section 9.4.8.3: this is the correct way to send
        RUN command + frequency setpoint atomically (avoids exception code 03H
        that occurs when two separate func-06H frames are sent back-to-back).

        Frame: SlaveID 10H RegHi RegLo CountHi CountLo ByteCount [Val0Hi Val0Lo ...] CRC
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
            # Response: SlaveID 10H RegHi RegLo CountHi CountLo CRC  (6 bytes)
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

    def set_frequency(self, hz: float):
        """Write frequency setpoint only (while already running)."""
        val = int(round(hz * 100))
        return self._wr(self.REG_FREQ_SET, val)

    def rpm_to_hz(self, rpm: float) -> float:
        return (rpm * POLES) / 120.0

    def run_forward(self):
        return self._wr(self.REG_CTRL, self.CMD_FWD)

    def run_reverse(self):
        return self._wr(self.REG_CTRL, self.CMD_REV)

    def stop(self):
        return self._wr(self.REG_CTRL, self.CMD_STOP)

    def coast_stop(self):
        return self._wr(self.REG_CTRL, self.CMD_COAST)

    def read_monitor(self):
        """Read monitoring data.

        PRIMARY -- P17 group (0x1100-0x1105): only readable while RUNNING.
        FALLBACK -- Base block (0x0000-0x0002): always readable.
        Returns dict with source="P17" or source="base", or None if both fail.
        """
        r1 = self._rd(self.REG_SET_FREQ, count=2)    # 0x1100, 0x1101
        r2 = self._rd(self.REG_OUT_VOLT, count=3)    # 0x1103, 0x1104, 0x1105

        if r1 is not None and r2 is not None:
            return {
                "set_freq":  r1[0] / 100.0,
                "out_freq":  r1[1] / 100.0,
                "out_volt":  r2[0],
                "out_curr":  r2[1] / 10.0,
                "motor_rpm": r2[2],
                "source":    "P17",
            }

        rb = self._rd(self.REG_BASE_SETFREQ, count=3)
        if rb is not None:
            return {
                "set_freq":  rb[0] / 100.0,
                "out_freq":  rb[1] / 100.0,
                "out_volt":  rb[2],
                "out_curr":  0.0,
                "motor_rpm": 0,
                "source":    "base",
            }

        return None

    def read_power(self, mon: dict) -> dict:
        """Derive power metrics from monitor dict.

        Power = sqrt(3) x V x I x PF  (3-phase).
        PF assumed 0.85 for loaded induction motor, 0.0 when stopped.
        Returns dict: voltage, current, power, pf.
        """
        v  = mon.get("out_volt", 0.0)
        i  = mon.get("out_curr", 0.0)
        pf = 0.85 if i > 0.05 else 0.0
        pw = (3 ** 0.5) * v * i * pf if i > 0.05 else 0.0
        return {"voltage": v, "current": i, "power": pw, "pf": pf}

    def read_input_voltage(self) -> float:
        """Read AC input (supply) voltage in Volts.

        Reads DC bus register 0x110B (P17.11, unit = 1 V direct), then
        back-calculates AC line voltage: V_ac = V_dc / 1.35
        Example: 380 V supply -> DC bus ~513 V -> 513/1.35 = 380 V.

        Returns AC voltage in Volts, or 0.0 on failure.
        NOTE: 0x110B is a P17 register -- returns exception 6 when motor is
        stopped. Caller should treat 0.0 as "hold last displayed value".

        NOTE FOR CALLER: this already returns volts -- do NOT divide by 10 again.
        """
        regs = self._rd(self.REG_DC_VOLT, count=1)
        if regs is None:
            return 0.0
        v_dc = float(regs[0])
        return round(v_dc / 1.35, 1)

    def read_hdi_freq_rpm(self, pulses_per_rev: int = 1):
        """Read shaft RPM from HDI hardware frequency counter (register 0x3010).

        Unit = 0.01 Hz per count.
        Confirmed: raw=334 at 200 RPM -> 334/100=3.34 Hz -> x60=200.4 RPM
        Returns (rpm, freq_hz) or (0.0, 0.0) on failure.
        """
        regs = self._rd(self.REG_HDI_FREQ, count=1)
        if regs is None:
            return (0.0, 0.0)
        freq_hz = float(regs[0]) / 100.0
        rpm     = (freq_hz * 60.0) / max(pulses_per_rev, 1)
        return (round(rpm, 1), round(freq_hz, 2))

    def read_hdi_status(self):
        """Read HDI bit state from P17.12 register 0x110C, BIT8."""
        regs = self._rd(0x110C, count=1)
        if regs is None:
            return None
        return bool(regs[0] & 0x0100)

    def read_base_block(self):
        """Read full base block 0x0000-0x0005 (always readable). Returns dict or None."""
        rb = self._rd(0x0000, count=6)
        if rb is None:
            return None
        return {
            "set_freq": rb[0] / 100.0,
            "out_freq": rb[1] / 100.0,
            "out_volt": rb[2],
            "raw_0003": rb[3],
            "raw_0004": rb[4],
            "raw_0005": rb[5],
        }

    def read_status_word(self):
        """Read inverter status word 0x2100. Returns None gracefully on exception 6."""
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
        if self._serial:
            try:
                self._serial.close()
            except Exception:
                pass
            self._serial = None