"""
PZEM-004T Driver
================
Pure-pyserial Modbus RTU driver for PZEM-004T V3.0 AC power meter.
Extracted from motor_control.py.
"""

import time

try:
    from gd200a import get_shared_serial
except ImportError:
    pass


class PZEM004T:
    SLAVE = 0xF8   # general broadcast address

    def __init__(self, port, baud=9600, parity='N', stopbits=1):
        self.port     = port
        self.baud     = baud
        self.parity   = parity
        self.stopbits = stopbits
        self._serial  = None
        self.ok       = False
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
        need    = 100 - elapsed
        if need > 0:
            time.sleep(need / 1000.0)

    def connect(self):
        try:
            if "get_shared_serial" in globals():
                self._serial = get_shared_serial(self.port, self.baud, self.parity, self.stopbits)
            else:
                import serial as _ser
                self._serial = _ser.Serial(
                    self.port, self.baud, bytesize=8,
                    parity=self.parity, stopbits=self.stopbits,
                    timeout=1.0)
            self._serial.reset_input_buffer()
            time.sleep(0.10)
            result  = self._read_regs(0x0000, 1)
            self.ok = result is not None
        except Exception:
            self.ok = False
        return self.ok

    def _read_regs(self, reg: int, count: int):
        self._ifg()
        try:
            payload = bytes([self.SLAVE, 0x04,
                             (reg >> 8) & 0xFF, reg & 0xFF,
                             (count >> 8) & 0xFF, count & 0xFF])
            frame    = payload + self._crc16(payload)
            expected = 5 + count * 2
            self._serial.reset_input_buffer()
            self._serial.write(frame)
            time.sleep(0.10)
            rx = self._serial.read(expected + 4)
            self._last_tx = time.time()
            if not rx or len(rx) < 5 or rx[1] & 0x80 or rx[1] != 0x04:
                return None
            byte_count = rx[2]
            if len(rx) < 3 + byte_count:
                return None
            return [(rx[3+i*2] << 8) | rx[4+i*2] for i in range(byte_count // 2)] or None
        except Exception:
            self._last_tx = time.time()
            return None

    def read_all(self):
        if not self.ok or self._serial is None:
            return None
        v = self._read_regs(0x0000, 10)
        if v is None or len(v) < 9:
            return None
        return {
            "voltage": v[0] / 10.0,
            "current": ((v[2] << 16) | v[1]) / 1000.0,
            "power":   ((v[4] << 16) | v[3]) / 10.0,
            "energy":  (v[6] << 16) | v[5],
            "freq":    v[7] / 10.0,
            "pf":      v[8] / 100.0,
        }

    def disconnect(self):
        self.ok = False
        self._serial = None
