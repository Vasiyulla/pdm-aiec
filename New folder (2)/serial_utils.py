"""
Serial port utilities -- pure pyserial, no pymodbus dependency.

Auto-detect uses raw Modbus RTU frames (same as motor_control2.py GD200A driver)
to probe ports. This avoids all pymodbus version API issues (slave= / unit= / etc).
"""

import platform
import time

try:
    import serial.tools.list_ports
    _SERIAL = True
except ImportError:
    _SERIAL = False

SLAVE_ID    = 1
ALL_BAUDS   = [9600, 19200, 38400, 4800, 2400, 57600, 115200, 1200]
ALL_PARITIES = [
    ('N', 1),   # 8N1
    ('N', 2),   # 8N2
    ('E', 1),   # 8E1
    ('O', 1),   # 8O1
]


def _crc16(data: bytes) -> bytes:
    crc = 0xFFFF
    for b in data:
        crc ^= b
        for _ in range(8):
            crc = (crc >> 1) ^ 0xA001 if (crc & 1) else crc >> 1
    return bytes([crc & 0xFF, (crc >> 8) & 0xFF])


def list_serial_ports():
    """Return list of available serial port names."""
    if _SERIAL:
        return [p.device for p in serial.tools.list_ports.comports()]
    if platform.system() == "Windows":
        return [f"COM{i}" for i in range(1, 20)]
    return ["/dev/ttyUSB0", "/dev/ttyUSB1", "/dev/ttyACM0"]


def _probe_one(port, baud, parity, stopbits, timeout=1.0):
    """Probe a port for VFD or PZEM using raw Modbus RTU frames.

    Returns ("VFD", slave, baud, parity, stopbits) or
            ("PZEM", slave, baud, parity, stopbits) or None.
    """
    if not _SERIAL:
        return None
    try:
        import serial as _ser
        s = _ser.Serial(port, baud, bytesize=8, parity=parity,
                        stopbits=stopbits, timeout=timeout)
        s.reset_input_buffer()
        time.sleep(0.20)   # mandatory warmup -- VFD ignores frames sent immediately

        # ── Probe VFD: read holding register 0x0000, slave 1 (func 03H) ──────
        # This address always responds regardless of motor state.
        payload = bytes([SLAVE_ID, 0x03, 0x00, 0x00, 0x00, 0x01])
        frame   = payload + _crc16(payload)
        s.reset_input_buffer()
        s.write(frame)
        time.sleep(0.12)
        rx = s.read(16)
        if rx and len(rx) >= 5 and rx[0] == SLAVE_ID and rx[1] == 0x03 and not (rx[1] & 0x80):
            s.close()
            return ("VFD", SLAVE_ID, baud, parity, stopbits)

        # ── Probe PZEM: read input register 0x0000, slave 0xF8 (func 04H) ───
        PZEM_SLAVE = 0xF8
        payload = bytes([PZEM_SLAVE, 0x04, 0x00, 0x00, 0x00, 0x01])
        frame   = payload + _crc16(payload)
        s.reset_input_buffer()
        s.write(frame)
        time.sleep(0.12)
        rx = s.read(16)
        if rx and len(rx) >= 5 and rx[0] == PZEM_SLAVE and rx[1] == 0x04 and not (rx[1] & 0x80):
            s.close()
            return ("PZEM", PZEM_SLAVE, baud, parity, stopbits)

        s.close()
    except Exception:
        pass
    return None


def auto_detect_devices(baud_list=None, callback=None):
    """Scan every port x baud x parity and detect VFD/PZEM.

    Returns dict with keys "VFD", "PZEM", "log".
    """
    ports = list_serial_ports()
    result = {"VFD": None, "PZEM": None, "log": []}
    bauds = baud_list if baud_list else ALL_BAUDS

    def log(msg):
        result["log"].append(msg)
        if callback:
            callback(msg)

    if not ports:
        log("No serial ports found on this system.")
        log("Install pyserial:  pip install pyserial")
        return result

    log(f"Found {len(ports)} port(s): {', '.join(ports)}")
    log(f"Will try {len(bauds)} baud rates x {len(ALL_PARITIES)} parity settings ...")
    log("")

    for port in ports:
        log(f"-- Port: {port} --")
        found_on_port = False

        for baud in bauds:
            for (parity, stopbits) in ALL_PARITIES:
                par_str = f"{baud}/{parity}8{stopbits}"
                log(f"  Trying {port}  {par_str} ...")

                hit = _probe_one(port, baud, parity, stopbits, timeout=0.55)
                if hit is None:
                    log(f"  -  no response")
                    continue

                kind, slave, b, par, sb = hit
                cfg = {"port": port, "baud": b,
                       "parity": par, "stopbits": sb, "slave": slave}

                if kind == "VFD" and result["VFD"] is None:
                    result["VFD"] = cfg
                    log(f"  OK  {port} -> GD200A VFD  "
                        f"(slave={slave}, {b} baud, {par}8{sb})")
                    found_on_port = True
                elif kind == "PZEM" and result["PZEM"] is None:
                    result["PZEM"] = cfg
                    log(f"  OK  {port} -> PZEM-004T  "
                        f"(slave=0x{slave:02X}, {b} baud, {par}8{sb})")
                    found_on_port = True

                if result["VFD"] and result["PZEM"]:
                    log("")
                    log("Both devices identified -- scan complete.")
                    return result

                if found_on_port:
                    break
            if found_on_port:
                break

    log("")
    if not result["VFD"]:
        log("GD200A VFD NOT detected.")
        log("  -> On VFD keypad set: P14.00=1  P14.01=3  P14.02=0  P14.04=0.0")
        log("  -> Try swapping RS-485 A+/B- wires")
    if not result["PZEM"]:
        log("PZEM-004T NOT detected.")
        log("  -> Check USB-TTL connected and module is powered")
    return result