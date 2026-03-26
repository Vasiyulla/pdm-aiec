"""Dialogs: PortDialog and DiagDialog for the motor dashboard."""
import tkinter as tk
import customtkinter as ctk
import threading
import time

from config import BG, CARD, BORDER, BORDER2, BLUE, BLUE_G, ORANGE, RED, SLATE, SLATE2, SLATE3, FU, FM, TEAL
from widgets import ArcGauge, abtn
from serial_utils import list_serial_ports

SLAVE_ID = 1

class PortDialog(ctk.CTkToplevel):
    """
    Simple manual port entry dialog.
    User types the COM port name for VFD and (optionally) PZEM.
    No scanning, no auto-detect — instant.
    """
    def __init__(self, parent):
        super().__init__(parent)
        self.title("Connect to Devices")
        self.geometry("420x340")
        self.configure(fg_color=BG)
        self.resizable(False, False)
        self.grab_set()

        self.result    = {"VFD": None, "PZEM": None}
        self.confirmed = False

        # ── Header bar ────────────────────────────────────────────────────────
        tk.Frame(self, bg=BLUE, height=4).pack(fill=tk.X)
        hf = tk.Frame(self, bg=CARD)
        hf.pack(fill=tk.X)
        tk.Label(hf, text="⚙  Serial Port Configuration",
                 bg=CARD, fg=SLATE, font=(FU, 13, "bold"),
                 anchor="w", padx=14, pady=10).pack(fill=tk.X)
        tk.Frame(self, bg=BORDER, height=1).pack(fill=tk.X)

        body = tk.Frame(self, bg=BG)
        body.pack(fill=tk.BOTH, expand=True, padx=20, pady=16)

        def _row(parent, label, hint, default):
            f = tk.Frame(parent, bg=BG)
            f.pack(fill=tk.X, pady=6)
            tk.Label(f, text=label, bg=BG, fg=SLATE,
                     font=(FU, 11, "bold"), width=14, anchor="w").pack(side=tk.LEFT)
            var = tk.StringVar(value=default)
            e = ctk.CTkEntry(f, textvariable=var, width=180,
                             placeholder_text=hint,
                             fg_color=CARD, text_color=SLATE,
                             border_color=BORDER2, font=(FM, 12))
            e.pack(side=tk.LEFT)
            return var

        # ── VFD port ──────────────────────────────────────────────────────────
        tk.Label(body, text="GD200A  VFD", bg=BG, fg=SLATE2,
                 font=(FU, 10, "bold")).pack(anchor="w", pady=(0, 2))
        self._vfd_port = _row(body, "COM Port:", "e.g. COM7", "COM7")
        self._vfd_baud = _row(body, "Baud Rate:", "9600", "9600")

        tk.Frame(body, bg=BORDER, height=1).pack(fill=tk.X, pady=8)

        # ── PZEM port ─────────────────────────────────────────────────────────
        tk.Label(body, text="PZEM-004T  Power Meter  (optional — leave blank to skip)",
                 bg=BG, fg=SLATE2, font=(FU, 10, "bold")).pack(anchor="w", pady=(0, 2))
        self._pzem_port = _row(body, "COM Port:", "blank = skip", "")
        self._pzem_baud = _row(body, "Baud Rate:", "9600", "9600")

        # ── Buttons ───────────────────────────────────────────────────────────
        btnf = tk.Frame(self, bg=BG)
        btnf.pack(fill=tk.X, padx=20, pady=(0, 16))

        abtn(btnf, "  ✔  CONNECT", BLUE,
             self._proceed, width=160, height=38).pack(side=tk.LEFT, padx=(0, 8))
        abtn(btnf, "✕  Cancel", SLATE3,
             self.destroy, width=100, height=38).pack(side=tk.LEFT)
        abtn(btnf, "🔧 Diagnose", ORANGE,
             self._open_diag, width=120, height=38).pack(side=tk.RIGHT)

    def _open_diag(self):
        DiagDialog(self)

    def _proceed(self):
        vport = self._vfd_port.get().strip()
        try:
            vbaud = int(self._vfd_baud.get().strip() or 9600)
        except ValueError:
            vbaud = 9600
        pport = self._pzem_port.get().strip()
        try:
            pbaud = int(self._pzem_baud.get().strip() or 9600)
        except ValueError:
            pbaud = 9600

        if vport:
            self.result["VFD"] = {"port": vport, "baud": vbaud,
                                  "parity": "N", "stopbits": 1, "slave": 1}
        if pport:
            self.result["PZEM"] = {"port": pport, "baud": pbaud,
                                   "parity": "N", "stopbits": 1, "slave": 0xF8}
        self.confirmed = True
        self.destroy()


# ═════════════════════════════════════════════════════════════════════════════
# RAW DIAGNOSTICS DIALOG
# ═════════════════════════════════════════════════════════════════════════════
class DiagDialog(ctk.CTkToplevel):
    """
    Hardware-level diagnostics window.

    Tests performed:
    1. PORT OPEN   — can pyserial open the COM port at all?
    2. VFD RAW     — sends multiple raw Modbus frames and shows raw hex reply.
                     Now includes the 0x0000 base register probe frame which
                     is confirmed to work even when motor is stopped.
    3. PZEM RAW    — sends a valid Modbus read-input-registers frame for
                     slave 0xF8 / register 0x0000 and shows raw hex reply.
    4. LISTEN 2s   — opens port and listens for any spontaneous bytes.

    What each result means:
      Port OPEN fails    → driver not installed or port in use by another app
      VFD reply on 0x0000 → device alive, use this address for probing
      Exception code 6   → register busy/locked (normal for P17 when stopped)
      0 bytes received   → wiring open-circuit or A/B swapped
      Wrong bytes        → baud/parity mismatch
    """

    # Pre-calculated raw Modbus RTU frames (CRC included)
    # Read 1 holding reg at 0x1101, slave 1 (func 03H):    01 03 11 01 00 01 D4 36
    VFD_FRAME       = bytes([0x01, 0x03, 0x11, 0x01, 0x00, 0x01, 0xD4, 0x36])
    # Read 1 input reg at 0x1101, slave 1 (func 04H):      01 04 11 01 00 01 CA D9
    VFD_FRAME_INPUT = bytes([0x01, 0x04, 0x11, 0x01, 0x00, 0x01, 0xCA, 0xD9])
    # Read 0x2100 (status word) func 03H:                  01 03 21 00 00 01 D3 C8
    VFD_STATUS      = bytes([0x01, 0x03, 0x21, 0x00, 0x00, 0x01, 0xD3, 0xC8])
    # Read base register 0x0000 func 03H (always readable):01 03 00 00 00 01 84 0A
    VFD_ADDR0       = bytes([0x01, 0x03, 0x00, 0x00, 0x00, 0x01, 0x84, 0x0A])
    # Read PZEM input reg 0x0000, slave 0xF8:              F8 04 00 00 00 01 A1 C0
    PZEM_FRAME      = bytes([0xF8, 0x04, 0x00, 0x00, 0x00, 0x01, 0xA1, 0xC0])

    def __init__(self, parent):
        super().__init__(parent)
        self.title("Hardware Diagnostics")
        self.geometry("700x820")
        self.configure(fg_color=BG)
        self.grab_set()

        tk.Frame(self, bg=ORANGE, height=4).pack(fill=tk.X)
        tk.Label(self, text="  🔧  Hardware Diagnostics — Raw Serial Test",
                 bg=CARD, fg=SLATE, font=(FU, 13, "bold"),
                 anchor="w", padx=14, pady=10).pack(fill=tk.X)
        tk.Frame(self, bg=BORDER, height=1).pack(fill=tk.X)

        inst = (
            "Sends raw Modbus bytes and shows exactly what comes back.\n"
            "NOTE: Exception code 6 on P17 registers (0x11xx) is NORMAL when motor is stopped.\n"
            "Use 'Probe 0x0000' to confirm the link, then 'Reg Scanner' to find all "
            "readable addresses, then 'Write+Run Test' to verify motor start."
        )
        tk.Label(self, text=inst, bg=BG, fg=SLATE2,
                 font=(FU, 10), justify="left", anchor="w",
                 padx=14, pady=6).pack(fill=tk.X)

        # ── Port / Baud / Parity selector ─────────────────────────────────────
        sf = tk.Frame(self, bg=BG)
        sf.pack(fill=tk.X, padx=14, pady=4)

        ports = list_serial_ports() or ["COM3", "COM4", "COM6"]
        tk.Label(sf, text="Port:", bg=BG, fg=SLATE2,
                 font=(FU, 11), width=6, anchor="w").pack(side=tk.LEFT)
        self._port_var = tk.StringVar(value=ports[0] if ports else "COM3")
        ctk.CTkComboBox(sf, values=ports, variable=self._port_var,
                        width=110, height=32, fg_color=CARD,
                        text_color=SLATE, border_color=BORDER2,
                        font=(FM, 12)).pack(side=tk.LEFT, padx=(0, 14))

        tk.Label(sf, text="Baud:", bg=BG, fg=SLATE2,
                 font=(FU, 11), width=5, anchor="w").pack(side=tk.LEFT)
        self._baud_var = tk.StringVar(value="9600")
        ctk.CTkComboBox(sf, values=["1200","2400","4800","9600","19200","38400","57600","115200"],
                        variable=self._baud_var,
                        width=110, height=32, fg_color=CARD,
                        text_color=SLATE, border_color=BORDER2,
                        font=(FM, 12)).pack(side=tk.LEFT, padx=(0, 14))

        tk.Label(sf, text="Parity:", bg=BG, fg=SLATE2,
                 font=(FU, 11), width=6, anchor="w").pack(side=tk.LEFT)
        self._par_var = tk.StringVar(value="N")
        ctk.CTkComboBox(sf, values=["N", "E", "O"],
                        variable=self._par_var,
                        width=70, height=32, fg_color=CARD,
                        text_color=SLATE, border_color=BORDER2,
                        font=(FM, 12)).pack(side=tk.LEFT)

        # ── Row 1: basic tests ─────────────────────────────────────────────────
        bf1 = tk.Frame(self, bg=BG)
        bf1.pack(fill=tk.X, padx=14, pady=(6, 2))
        tk.Label(bf1, text="Basic:", bg=BG, fg=SLATE2,
                 font=(FU, 10, "bold"), width=7, anchor="w").pack(side=tk.LEFT)
        for txt, col, cmd in [
            ("1. Open Port",        BLUE,   self._test_open),
            ("2. VFD P17 Regs",     TEAL,   self._test_vfd),
            ("3. Probe 0x0000",     BLUE_G, self._test_vfd_probe),
            ("4. PZEM Read",        PURPLE, self._test_pzem),
            ("5. Listen 2s",        ORANGE, self._test_listen),
        ]:
            abtn(bf1, txt, col, cmd, width=112, height=34).pack(
                side=tk.LEFT, padx=(0, 4))

        # ── Row 2: advanced tests ──────────────────────────────────────────────
        bf2 = tk.Frame(self, bg=BG)
        bf2.pack(fill=tk.X, padx=14, pady=(2, 6))
        tk.Label(bf2, text="Advanced:", bg=BG, fg=SLATE2,
                 font=(FU, 10, "bold"), width=7, anchor="w").pack(side=tk.LEFT)
        abtn(bf2, "6. Reg Scanner", SLATE,  self._test_reg_scan,
             width=140, height=34).pack(side=tk.LEFT, padx=(0, 4))
        abtn(bf2, "7. Write + Run Test", RED, self._test_write_run,
             width=160, height=34).pack(side=tk.LEFT, padx=(0, 4))
        abtn(bf2, "8. Read 0x0000–0x0009", TEAL, self._test_base_block,
             width=190, height=34).pack(side=tk.LEFT, padx=(0, 4))

        # ── Results box ────────────────────────────────────────────────────────
        tk.Frame(self, bg=BORDER, height=1).pack(fill=tk.X, pady=(4, 0))
        tk.Label(self, text="  Results:", bg=BG, fg=SLATE2,
                 font=(FU, 10, "bold")).pack(anchor="w", padx=14, pady=(6, 2))

        self._out = tk.Text(self, height=20, bg=CARD, fg=SLATE,
                            font=(FM, 10), bd=0, relief=tk.FLAT,
                            state=tk.DISABLED, padx=10, pady=8,
                            wrap=tk.WORD)
        self._out.pack(fill=tk.BOTH, expand=True, padx=10, pady=(0, 4))

        sb = tk.Scrollbar(self, command=self._out.yview, bg=BG)
        self._out.configure(yscrollcommand=sb.set)

        legend = (
            "Legend:  TX = bytes sent  |  RX = bytes received\n"
            "0 bytes RX      → open circuit / A+B- swapped / wrong slave\n"
            "Exception 6 RX  → register busy/locked (normal for P17 when stopped)\n"
            "Garbled RX      → baud or parity mismatch\n"
            "Valid RX        → device alive and comm settings correct"
        )
        tk.Label(self, text=legend, bg=BG, fg=SLATE2,
                 font=(FU, 9), justify="left", anchor="w",
                 padx=14, pady=4).pack(fill=tk.X)

        self._diag("Diagnostics ready.  Select a port and click a test button.")
        self._diag(f"Available ports: {', '.join(ports)}")
        self._diag("")
        self._diag("CHECKLIST before testing:")
        self._diag("  □ USB-RS485 adapter plugged in and driver installed")
        self._diag("  □ VFD powered ON (fans/display running)")
        self._diag("  □ RS-485 A+ → VFD terminal TA  and  B- → VFD terminal TB")
        self._diag("  □ VFD P14.00=1  P14.01=3  P14.02=0  P14.04=0.0")
        self._diag("  □ If still failing: swap A+ and B- wires (very common)")
        self._diag("")
        self._diag("TIP: Confirmed working on COM7/9600/N81/slave=1:")
        self._diag("  • 'Probe 0x0000'       → value=2 (link alive)")
        self._diag("  • P17 regs (0x11xx)    → exception 6 (normal when stopped)")
        self._diag("  • 'Reg Scanner'        → finds ALL readable addresses")
        self._diag("  • 'Write + Run Test'   → sends RESET + freq + FORWARD, reads back")

    def _diag(self, msg, color=None):
        self._out.configure(state=tk.NORMAL)
        self._out.insert(tk.END, msg + "\n")
        self._out.see(tk.END)
        self._out.configure(state=tk.DISABLED)

    def _port(self):    return self._port_var.get()
    def _baud(self):    return int(self._baud_var.get())
    def _parity(self):  return self._par_var.get()

    def _test_open(self):
        import serial
        port = self._port()
        self._diag(f"\n── Test 1: Open {port} ──")
        try:
            s = serial.Serial(port, self._baud(), timeout=0.5,
                              parity=self._parity(), stopbits=1)
            self._diag(f"  ✓  Port {port} opened successfully")
            self._diag(f"     Baud={self._baud()}  Parity={self._parity()}  "
                       f"CTS={s.getCTS()}  DSR={s.getDSR()}")
            s.close()
            self._diag("  ✓  Port closed cleanly")
        except Exception as e:
            self._diag(f"  ✗  FAILED to open {port}: {e}")
            self._diag("     → Another app (Modbus Poll, PuTTY etc.) may be using this port")
            self._diag("     → Try closing other apps and re-running test")

    def _send_raw(self, frame, label):
        import serial
        port, baud, par = self._port(), self._baud(), self._parity()
        self._diag(f"\n── {label} on {port} @ {baud}/{par}81 ──")
        try:
            s = serial.Serial(port, baud, timeout=0.8,
                              parity=par, stopbits=1, bytesize=8)
            s.reset_input_buffer()
            tx_hex = " ".join(f"{b:02X}" for b in frame)
            self._diag(f"  TX ({len(frame)} bytes):  {tx_hex}")
            s.write(frame)
            time.sleep(0.1)
            raw = s.read(64)
            s.close()

            if not raw:
                self._diag(f"  RX:  *** 0 bytes received ***")
                self._diag("       Possible causes:")
                self._diag("         1. A+ and B- wires are SWAPPED — try swapping them")
                self._diag("         2. Device not powered / not connected")
                self._diag("         3. Baud rate mismatch — try other baud rates")
                self._diag("         4. RS-485 adapter TX not working")
                self._diag("         5. VFD in CE fault — power cycle VFD")
            else:
                rx_hex = " ".join(f"{b:02X}" for b in raw)
                self._diag(f"  RX ({len(raw)} bytes):  {rx_hex}")
                self._diag(f"  ASCII: {repr(raw)}")
                self._interpret(frame, raw, label)

        except Exception as e:
            self._diag(f"  ✗  Error: {e}")

    def _interpret(self, tx, rx, label):
        if len(rx) < 3:
            self._diag("  ⚠  Too few bytes — partial response (noise or wrong baud)")
            return

        slave_echo     = rx[0]
        func_echo      = rx[1]
        expected_slave = tx[0]

        if slave_echo != expected_slave:
            self._diag(f"  ⚠  Slave address mismatch: sent {expected_slave:#04x} "
                       f"got {slave_echo:#04x}")
            return

        if func_echo & 0x80:
            err_code = rx[2] if len(rx) > 2 else 0
            codes = {1: "Illegal function", 2: "Illegal address",
                     3: "Illegal value",    4: "Device failure",
                     6: "Slave busy / register locked (normal for P17 when stopped)"}
            self._diag(f"  ⚠  Modbus exception from device: "
                       f"code {err_code} = {codes.get(err_code, 'Unknown')}")
            if err_code == 6:
                self._diag("      → This is EXPECTED for P17 registers when motor is stopped.")
                self._diag("      → Use 'VFD Probe 0x0000' to confirm the link is alive.")
        else:
            self._diag(f"  ✓  Valid Modbus response!  slave=0x{slave_echo:02X}  "
                       f"func=0x{func_echo:02X}")
            if "P17" in label or "0x1101" in label:
                if len(rx) >= 5:
                    val = (rx[3] << 8) | rx[4]
                    self._diag(f"  ✓  GD200A output freq = {val}  ({val/100.0:.2f} Hz)")
            elif "0x0000" in label or "Probe" in label:
                if len(rx) >= 5:
                    val = (rx[3] << 8) | rx[4]
                    self._diag(f"  ✓  Base register value = {val}  "
                               f"(link confirmed alive — ignore raw value)")
            elif "PZEM" in label:
                if len(rx) >= 5:
                    val = (rx[3] << 8) | rx[4]
                    self._diag(f"  ✓  PZEM voltage register = {val}  ({val/10.0:.1f} V)")

    def _test_vfd(self):
        """Test P17 registers — expect exception 6 when motor is stopped."""
        self._diag("\n══ VFD P17 Register Tests (may return exc.6 when stopped) ══")
        self._send_raw(self.VFD_FRAME,       "VFD P17: func 03H (holding), addr=0x1101")
        self._diag("")
        self._send_raw(self.VFD_FRAME_INPUT, "VFD P17: func 04H (input),   addr=0x1101")
        self._diag("")
        self._send_raw(self.VFD_STATUS,      "VFD P17: func 03H (holding), addr=0x2100 (status)")

    def _test_vfd_probe(self):
        """Test base register 0x0000 — always readable, confirms link is alive."""
        self._diag("\n══ VFD Probe 0x0000 (always readable — use this to confirm link) ══")
        self._send_raw(self.VFD_ADDR0, "VFD Probe: func 03H (holding), addr=0x0000")

    def _test_pzem(self):
        self._send_raw(self.PZEM_FRAME, "PZEM Raw Read (slave=0xF8, reg=0x0000)")

    def _test_listen(self):
        import serial
        port, baud, par = self._port(), self._baud(), self._parity()
        self._diag(f"\n── Test 5: Listen on {port} for 2 seconds ──")
        self._diag("  (useful to check if device is sending anything unsolicited)")
        try:
            s = serial.Serial(port, baud, timeout=2.0, parity=par,
                              stopbits=1, bytesize=8)
            s.reset_input_buffer()
            self._diag("  Listening …")
            raw = s.read(128)
            s.close()
            if raw:
                rx_hex = " ".join(f"{b:02X}" for b in raw)
                self._diag(f"  ✓  Received {len(raw)} bytes: {rx_hex}")
            else:
                self._diag("  –  0 bytes received in 2 seconds (device is silent)")
        except Exception as e:
            self._diag(f"  ✗  Error: {e}")

    # ── Test 6: Register Range Scanner ───────────────────────────────────────
    def _test_reg_scan(self):
        """
        Scan a set of known GD200A register ranges using pymodbus.
        Runs in a background thread so the UI stays responsive.
        Reports every register that returns a valid (non-exception) response
        along with its raw value, so we know exactly what this firmware exposes
        while the motor is stopped.
        """
        self._diag("\n══ Test 6: Register Scanner (runs in background) ══")
        self._diag("  Scanning known GD200A address ranges via pymodbus …")
        self._diag("  This may take 10-20 seconds depending on firmware response time.")
        self._diag("")

        # Ranges to scan: (start_addr, count, label, func)
        # func: "h" = holding (03H), "i" = input (04H)
        RANGES = [
            (0x0000, 16,   "Base block 0x0000-0x000F",     "h"),
            (0x1000, 16,   "P16 group  0x1000-0x100F",     "h"),
            (0x1100, 16,   "P17 group  0x1100-0x110F",     "h"),
            (0x2000,  4,   "Control    0x2000-0x2003",     "h"),
            (0x2100,  4,   "Status     0x2100-0x2103",     "h"),
            (0x3000, 16,   "P-param    0x3000-0x300F",     "h"),
            (0x0000, 16,   "Base block 0x0000-0x000F",     "i"),
            (0x1100, 16,   "P17 group  0x1100-0x110F",     "i"),
        ]

        def _scan():
            port, baud, par = self._port(), self._baud(), self._parity()
            try:
                import serial as _ser
                _s = _ser.Serial(port, baud, bytesize=8, parity=par,
                                 stopbits=1, timeout=0.6)
                _s.reset_input_buffer()
                time.sleep(0.20)
            except Exception as ex:
                self.after(0, lambda: self._diag(f"  ✗  Port error: {ex}"))
                return

            def _crc16(data):
                crc = 0xFFFF
                for b in data:
                    crc ^= b
                    for _ in range(8):
                        crc = (crc >> 1) ^ 0xA001 if (crc & 1) else crc >> 1
                return bytes([crc & 0xFF, (crc >> 8) & 0xFF])

            def _rd_raw(reg, count, func_h):
                fn = 0x03 if func_h else 0x04
                payload = bytes([SLAVE_ID, fn, (reg>>8)&0xFF, reg&0xFF,
                                  (count>>8)&0xFF, count&0xFF])
                frame = payload + _crc16(payload)
                _s.reset_input_buffer()
                _s.write(frame)
                time.sleep(0.09)
                rx = _s.read(5 + count*2 + 4)
                if not rx or len(rx) < 5 or rx[0] != SLAVE_ID:
                    return None
                if rx[1] & 0x80:
                    return None
                if rx[1] != fn:
                    return None
                bc = rx[2]
                regs = []
                for i2 in range(bc // 2):
                    regs.append((rx[3+i2*2] << 8) | rx[4+i2*2])
                return regs if regs else None

            found = []
            for start, count, label, func in RANGES:
                fn = "03H holding" if func == "h" else "04H input"
                hdr = f"  ── {label}  ({fn}) ──"
                self.after(0, lambda m=hdr: self._diag(m))
                time.sleep(0.05)

                # Try reading the whole range first (faster)
                regs_r = _rd_raw(start, count, func == "h")
                if regs_r is not None:
                    for i, v in enumerate(regs_r):
                        addr = start + i
                        msg = (f"    0x{addr:04X}  = {v:5d}  "
                               f"(0x{v:04X}  /  {v/100:.2f} Hz if freq  "
                               f"/  {v/10:.1f} A if curr)")
                        self.after(0, lambda m=msg: self._diag(m))
                        found.append((addr, v, func))
                    time.sleep(0.05)
                    continue

                # Range read failed (e.g. exception 6) — probe register by register
                for offset in range(count):
                    addr = start + offset
                    time.sleep(0.06)
                    reg1 = _rd_raw(addr, 1, func == "h")
                    if reg1 is not None:
                        v = reg1[0]
                        msg = (f"    0x{addr:04X}  = {v:5d}  "
                               f"(0x{v:04X}  /  {v/100:.2f} Hz if freq  "
                               f"/  {v/10:.1f} A if curr)")
                        self.after(0, lambda m=msg: self._diag(m))
                        found.append((addr, v, func))
                    time.sleep(0.02)

            _s.close()
            summary = (f"\n  ── Scan complete.  {len(found)} readable register(s) found. ──\n"
                       f"  These addresses work while motor is STOPPED.\n"
                       f"  Start the motor and re-scan to see P17 (0x11xx) values appear.")
            self.after(0, lambda: self._diag(summary))

        threading.Thread(target=_scan, daemon=True).start()

    # ── Test 7: Write + Run Test ──────────────────────────────────────────────
    def _test_write_run(self):
        """
        Step-by-step write test:
          1. Send RESET (0x0007 → 0x2000)    — clear any CE fault
          2. Send freq 25 Hz (2500 → 0x2001) — safe test speed
          3. Read back 0x2001                 — verify write accepted
          4. Send FORWARD (0x0001 → 0x2000)  — start motor
          5. Wait 1.5 s, then read 0x0000     — confirm any change in base reg
          6. Send STOP (0x0005 → 0x2000)     — always stop at end

        ⚠ WARNING: This will attempt to START the motor at 25 Hz.
          Only run if the motor is free to rotate safely.
        """
        self._diag("\n══ Test 7: Write + Run Test  ⚠ MOTOR WILL START ══")
        self._diag("  Sequence: RESET → freq 25 Hz → FORWARD → wait → read → STOP")
        self._diag("  ⚠  Motor will start at ~750 RPM for ~1.5 seconds then stop.")
        self._diag("")

        def _crc16(data: bytes) -> bytes:
            crc = 0xFFFF
            for b in data:
                crc ^= b
                for _ in range(8):
                    crc = (crc >> 1) ^ 0xA001 if (crc & 1) else crc >> 1
            return bytes([crc & 0xFF, (crc >> 8) & 0xFF])

        def _wr_frame(reg: int, val: int) -> bytes:
            """Build a Modbus func 06H single-register write frame with CRC."""
            payload = bytes([SLAVE_ID, 0x06,
                             (reg >> 8) & 0xFF, reg & 0xFF,
                             (val >> 8) & 0xFF, val & 0xFF])
            return payload + _crc16(payload)

        def _rd_frame(reg: int, count: int = 1) -> bytes:
            """Build a Modbus func 03H read frame with CRC."""
            payload = bytes([SLAVE_ID, 0x03,
                             (reg >> 8) & 0xFF, reg & 0xFF,
                             (count >> 8) & 0xFF, count & 0xFF])
            return payload + _crc16(payload)

        def _run():
            import serial as _serial
            port, baud, par = self._port(), self._baud(), self._parity()
            steps = [
                ("RESET fault",     _wr_frame(0x2000, 0x0007), False),
                ("Set freq 25 Hz",  _wr_frame(0x2001, 2500),   False),
                ("Read back 0x2001",_rd_frame(0x2001, 1),       True),
                ("FORWARD run",     _wr_frame(0x2000, 0x0001), False),
            ]
            try:
                s = _serial.Serial(port, baud, timeout=1.0,
                                   parity=par, stopbits=1, bytesize=8)
                s.reset_input_buffer()
            except Exception as ex:
                self.after(0, lambda: self._diag(f"  ✗  Cannot open {port}: {ex}"))
                return

            for step_label, frame, is_read in steps:
                tx_hex = " ".join(f"{b:02X}" for b in frame)
                self.after(0, lambda l=step_label, h=tx_hex:
                           self._diag(f"\n  [{l}]  TX: {h}"))
                time.sleep(0.15)
                s.reset_input_buffer()
                s.write(frame)
                time.sleep(0.12)
                rx = s.read(64)
                rx_hex = " ".join(f"{b:02X}" for b in rx) if rx else "(no reply)"
                self.after(0, lambda h=rx_hex: self._diag(f"           RX: {h}"))

                if not rx:
                    self.after(0, lambda: self._diag(
                        "  ✗  No response — write command not acknowledged"))
                elif len(rx) >= 2 and rx[1] & 0x80:
                    ec = rx[2] if len(rx) > 2 else 0
                    self.after(0, lambda c=ec: self._diag(
                        f"  ✗  Modbus exception {c} — command rejected by VFD"))
                else:
                    if is_read and len(rx) >= 5:
                        val = (rx[3] << 8) | rx[4]
                        self.after(0, lambda v=val: self._diag(
                            f"  ✓  Read back 0x2001 = {v}  ({v/100:.2f} Hz) — write confirmed"))
                    else:
                        self.after(0, lambda: self._diag(
                            "  ✓  Acknowledged — VFD accepted the command"))
                time.sleep(0.1)

            # Wait 1.5 s while motor (hopefully) accelerates
            self.after(0, lambda: self._diag("\n  Waiting 1.5 s for motor to respond …"))
            time.sleep(1.5)

            # Read base register — value may change if motor started
            rd_frame = _rd_frame(0x0000, 1)
            s.reset_input_buffer()
            s.write(rd_frame)
            time.sleep(0.12)
            rx = s.read(8)
            if rx and len(rx) >= 5 and not (rx[1] & 0x80):
                val = (rx[3] << 8) | rx[4]
                self.after(0, lambda v=val: self._diag(
                    f"  ✓  0x0000 after FORWARD = {v}  "
                    f"(was 2 at rest — changed: {'YES ← motor running!' if v != 2 else 'no'})"))
            else:
                self.after(0, lambda: self._diag(
                    "  –  Could not read 0x0000 after FORWARD"))

            # Always send STOP
            stop_frame = _wr_frame(0x2000, 0x0005)
            s.reset_input_buffer()
            s.write(stop_frame)
            time.sleep(0.15)
            rx = s.read(8)
            rx_hex = " ".join(f"{b:02X}" for b in rx) if rx else "(no reply)"
            self.after(0, lambda h=rx_hex: self._diag(
                f"\n  [STOP sent]  TX: {' '.join(f'{b:02X}' for b in stop_frame)}"
                f"  RX: {h}"))

            s.close()
            self.after(0, lambda: self._diag(
                "\n  ── Write+Run Test complete ──\n"
                "  ✔ If all steps showed 'Acknowledged', the VFD control link is working.\n"
                "  ✔ If 0x0000 changed from 2 → anything else, the motor started.\n"
                "  ✔ Now try FORWARD from the dashboard — P17 registers will be readable."))

        threading.Thread(target=_run, daemon=True).start()

    # ── Test 8: Read base block 0x0000–0x0009 ────────────────────────────────
    def _test_base_block(self):
        """
        Read 10 consecutive registers starting at 0x0000 and interpret all of
        them.  On this firmware version, 0x0000 is the only always-readable
        address.  Running this while the motor is stopped shows which adjacent
        registers are accessible and what their values mean.
        """
        self._diag("\n══ Test 8: Read base block 0x0000–0x0009 ══")

        # CRC-correct raw frame: slave=1, func=03H, addr=0x0000, count=10
        # Pre-calculated: 01 03 00 00 00 0A C5 CD
        frame = bytes([0x01, 0x03, 0x00, 0x00, 0x00, 0x0A, 0xC5, 0xCD])
        self._send_raw(frame, "Base block: func 03H, addr=0x0000, count=10")

        # Also try count=1 frames for each address individually
        # to isolate which ones respond and which don't
        self._diag("")
        self._diag("  Individual probes for addresses 0x0000–0x0009:")

        # Pre-calculated CRC frames for each address (func 03H, count=1, slave=1)
        addr_frames = {
            0x0000: bytes([0x01, 0x03, 0x00, 0x00, 0x00, 0x01, 0x84, 0x0A]),
            0x0001: bytes([0x01, 0x03, 0x00, 0x01, 0x00, 0x01, 0xD5, 0xCA]),
            0x0002: bytes([0x01, 0x03, 0x00, 0x02, 0x00, 0x01, 0x25, 0xCA]),
            0x0003: bytes([0x01, 0x03, 0x00, 0x03, 0x00, 0x01, 0x74, 0x0A]),
            0x0004: bytes([0x01, 0x03, 0x00, 0x04, 0x00, 0x01, 0xC5, 0xCB]),
            0x0005: bytes([0x01, 0x03, 0x00, 0x05, 0x00, 0x01, 0x94, 0x0B]),
        }
        labels = {
            0x0000: "setting freq?  (÷100 = Hz)",
            0x0001: "output freq?   (÷100 = Hz)",
            0x0002: "output volt?   (V direct)",
            0x0003: "output curr?   (÷10 = A)",
            0x0004: "motor RPM?     (direct)",
            0x0005: "DC bus volt?   (V direct)",
        }
        for addr, frm in addr_frames.items():
            lbl = labels.get(addr, "unknown")
            self._send_raw(frm, f"  addr=0x{addr:04X}  ({lbl})")


# ═════════════════════════════════════════════════════════════════════════════