"""
Driver for PZEM-004T V3.0 AC power meter -- pure pyserial, no pymodbus.

Protocol: Modbus-RTU, func 04H (Read Input Registers), 9600 8N1.
Slave address 0xF8 = general address (works in single-slave setups).

Register map (func 04H, per datasheet):
  0x0000  Voltage       /10   -> V
  0x0001  Current low   |
  0x0002  Current high  | combined /1000 -> A
  0x0003  Power low     |
  0x0004  Power high    | combined /10   -> W
  0x0005  Energy low    |
  0x0006  Energy high   | combined       -> Wh
  0x0007  Frequency     /10  -> Hz
  0x0008  Power factor  /100 -> (0-1)
  0x0009  Alarm status  0xFFFF=alarm
"""

import time


class PZEM004T:
    SLAVE = 0xF8   # general address

    def __init__(self, port, baud=9600, parity='N', stopbits=1):
        self.port      = port
        self.baud      = baud
        self.parity    = parity
        self.stopbits  = stopbits
        self._serial   = None
        self.ok        = False
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
        need = 100 - elapsed   # 100 ms between frames for PZEM
        if need > 0:
            time.sleep(need / 1000.0)

    def connect(self):
        try:
            import serial as _ser
            self._serial = _ser.Serial(
                self.port, self.baud, bytesize=8,
                parity=self.parity, stopbits=self.stopbits,
                timeout=1.0)
            self._serial.reset_input_buffer()
            time.sleep(0.10)
            result = self._read_regs(0x0000, 1)
            self.ok = result is not None
        except Exception:
            self.ok = False
        return self.ok

    def _read_regs(self, reg: int, count: int):
        """Send func 04H frame, return list of register values or None."""
        self._ifg()
        try:
            payload = bytes([self.SLAVE, 0x04,
                             (reg >> 8) & 0xFF, reg & 0xFF,
                             (count >> 8) & 0xFF, count & 0xFF])
            frame = payload + self._crc16(payload)
            self._serial.reset_input_buffer()
            self._serial.write(frame)
            expected = 5 + count * 2
            time.sleep(0.10)
            rx = self._serial.read(expected + 4)
            self._last_tx = time.time()
            if not rx or len(rx) < 5:
                return None
            if rx[1] & 0x80:
                return None
            if rx[1] != 0x04:
                return None
            byte_count = rx[2]
            if len(rx) < 3 + byte_count:
                return None
            regs = []
            for i in range(byte_count // 2):
                regs.append((rx[3 + i*2] << 8) | rx[4 + i*2])
            return regs if regs else None
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
        if self._serial:
            try:
                self._serial.close()
            except Exception:
                pass
            self._serial = None