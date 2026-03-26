import tkinter as tk
import customtkinter as ctk
from tkinter import messagebox, ttk
import threading, time, math, platform, queue

import matplotlib
matplotlib.use("TkAgg")
from matplotlib.backends.backend_tkagg import FigureCanvasTkAgg
from matplotlib.figure import Figure

ctk.set_appearance_mode("light")
ctk.set_default_color_theme("blue")

from config import *
from serial_utils import list_serial_ports, auto_detect_devices
from vfd import GD200A
from pzem import PZEM004T
from widgets import ArcGauge, PulseDot, MetricRow, card, abtn, _fget_e
from dialogs import PortDialog, DiagDialog


class MotorDashboard(ctk.CTk):

    def __init__(self):
        super().__init__()
        self.title("Smart Motor Control  —  INVT GD200A  |  Theem COE")
        self.geometry("1420x900")
        self.configure(fg_color=BG)
        self.resizable(True, True)

        self.vfd  = None
        self.pzem = None

        self.running   = False
        self.oc_trip_t = None
        self._prox_seen        = False
        self._prox_rpm         = 0.0

        self.c_spd, self.c_trq, self.c_cur = [], [], []

        # Previous values for optimization
        self._prev_rpm_vfd = 0
        self._prev_vfd_freq = 0
        self._prev_vfd_volt = 0
        self._prev_vfd_curr = 0
        self._prev_set_freq = 0
        self._prev_voltage = 0
        self._prev_current = 0
        self._prev_pf = 0
        self._prev_power = 0
        self._prev_inp_volt = 0
        self._prev_rpm_prox = 0
        self._prev_freq = 0

        self.current = 0.0
        self.rpm_vfd_val = 0.0

        self.update_queue = queue.Queue()
        self.polling_thread = None
        self.stop_polling = False

        self._build()
        self.after(300, self._run_scan)

    # ─────────────────────────────────────────────────────────────────────────
    # PORT CONFIG  → CONNECT
    # ─────────────────────────────────────────────────────────────────────────
    def _run_scan(self):
        dlg = PortDialog(self)
        self.wait_window(dlg)

        if not dlg.confirmed:
            self._log("Scan cancelled.")
            return

        r = dlg.result

        if r["VFD"]:
            cfg = r["VFD"]
            self.vfd = GD200A(cfg["port"], cfg["baud"],
                              cfg["parity"], cfg["stopbits"])
        else:
            self.vfd = None

        if r["PZEM"]:
            cfg = r["PZEM"]
            self.pzem = PZEM004T(cfg["port"], cfg["baud"],
                                  cfg["parity"], cfg["stopbits"])
        else:
            self.pzem = None

        self._connect_all()
        self.after(100, self._start_polling)

    def _start_polling(self):
        self.stop_polling = False
        self.polling_thread = threading.Thread(target=self._poll_thread, daemon=True)
        self.polling_thread.start()
        self.after(100, self._process_updates)

    def _rescan(self):
        if self.vfd:
            self.vfd.disconnect()
        if self.pzem:
            self.pzem.disconnect()
        self.vfd  = None
        self.pzem = None
        self._run_scan()

    def _connect_all(self):
        # ── VFD ──────────────────────────────────────────────────────────────
        if self.vfd:
            vok = self.vfd.connect()
            if vok:
                self._vfd_dot.set_state(True, color=TEAL)
                self._vfd_lbl.configure(text=f"VFD  {self.vfd.port}", fg=TEAL)
                self._log(f"GD200A connected on {self.vfd.port}  @{self.vfd.baud} baud")
                self._log("VFD probe register 0x0000 responded — link confirmed")
            else:
                self._vfd_dot.set_state(False)
                self._vfd_lbl.configure(
                    text=f"VFD  OFFLINE ({self.vfd.port})", fg=RED)
                self._log(f"VFD connect failed: {self.vfd.err or 'no response'}")
                self._log("Check: P00.01=2  P00.06=8  P14.01=3  P14.04=0.0")
                self._mark_vfd_na()
        else:
            self._vfd_dot.set_state(False)
            self._vfd_lbl.configure(text="VFD  NOT FOUND", fg=RED)
            self._log("GD200A not detected — click ↺ RESET FAULT or re-scan")
            self._mark_vfd_na()

        # ── PZEM ─────────────────────────────────────────────────────────────
        if self.pzem:
            pok = self.pzem.connect()
            if pok:
                self._pzem_dot.set_state(True, color=TEAL)
                self._pzem_lbl.configure(
                    text=f"PZEM  {self.pzem.port}", fg=TEAL)
                self._log(f"PZEM-004T connected on {self.pzem.port}  @{self.pzem.baud} baud")
            else:
                self._pzem_dot.set_state(False)
                self._pzem_lbl.configure(text="PZEM  OFFLINE", fg=RED)
                self._log("PZEM connect failed — check USB-TTL wiring")
                self._mark_pzem_na()
        else:
            self._pzem_dot.set_state(False)
            self._pzem_lbl.configure(text="PZEM  NOT FOUND", fg=RED)
            self._log("PZEM-004T not detected")
            self._mark_pzem_na()

        self._prox_dot.set_state(False)
        self._prox_lbl.configure(text="PROX  NOT CONNECTED", fg=SLATE3)
        self.g_rpm_prox.set_na()
        self.m["rpm_prox"].set_text("N/A")
        self._log("Proximity: reading HDI status from VFD reg 0x2101 — polling every 500ms")

    def _mark_pzem_na(self):
        self.m["freq"].set_text("N/A")

    def _mark_vfd_na(self):
        for k in ("inp_volt", "volt", "curr", "pow", "pf", "vfd_freq", "vfd_volt", "vfd_curr", "rpm_vfd", "rpm_prox", "setf"):
            self.m[k].set_text("N/A")
        for ph in self.m3:
            self.m3[ph].set_text("N/A")
        self.g_rpm_vfd.set_na()
        self.g_rpm_prox.set_na()
        self.g_curr.set_na()
        self.g_volt.set_na()
        self.g_pf.set_na()

    # ─────────────────────────────────────────────────────────────────────────
    # BUILD UI
    # ─────────────────────────────────────────────────────────────────────────
    def _build(self):
        hdr = tk.Frame(self, bg=CARD, height=66)
        hdr.pack(fill=tk.X)
        hdr.pack_propagate(False)
        tk.Frame(hdr, bg=BLUE, width=6).pack(side=tk.LEFT, fill=tk.Y)
        tk.Label(hdr, text="⚡", bg=CARD, fg=BLUE, font=(FU, 22)
                 ).pack(side=tk.LEFT, padx=(14, 6))
        tk.Label(hdr, text="SMART MOTOR CONTROL  —  INVT GD200A",
                 bg=CARD, fg=SLATE, font=(FU, 16, "bold")).pack(side=tk.LEFT)
        tk.Label(hdr,
                 text="  Laptop / PC  ·  VFD Modbus RTU  ·  HDI Proximity  ·  Theem COE",
                 bg=CARD, fg=SLATE2, font=(FU, 11)).pack(side=tk.LEFT, padx=10)

        bf = tk.Frame(hdr, bg=CARD)
        bf.pack(side=tk.RIGHT, padx=16)
        for da, la, txt in [("_vfd_dot",  "_vfd_lbl",  "VFD …"),
                             ("_pzem_dot", "_pzem_lbl", "PZEM …"),
                             ("_prox_dot", "_prox_lbl", "PROX …")]:
            f = tk.Frame(bf, bg=CARD)
            f.pack(side=tk.LEFT, padx=8)
            d = PulseDot(f, color=ORANGE, sz=14, bg=CARD)
            d.pack(side=tk.LEFT, padx=(0, 4), pady=26)
            l = tk.Label(f, text=txt, bg=CARD, fg=ORANGE, font=(FU, 10, "bold"))
            l.pack(side=tk.LEFT)
            setattr(self, da, d)
            setattr(self, la, l)

        abtn(hdr, "⚙ Re-Connect", BLUE, self._rescan,
             width=110, height=34).pack(side=tk.RIGHT, padx=(0, 8), pady=14)

        tk.Frame(self, bg=BORDER, height=2).pack(fill=tk.X)

        body = tk.Frame(self, bg=BG)
        body.pack(fill=tk.BOTH, expand=True, padx=14, pady=12)

        left  = tk.Frame(body, bg=BG, width=232)
        mid   = tk.Frame(body, bg=BG)
        right = tk.Frame(body, bg=BG, width=272)

        left.pack(side=tk.LEFT, fill=tk.Y, padx=(0, 10))
        mid.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)
        right.pack(side=tk.LEFT, fill=tk.Y, padx=(10, 0))
        left.pack_propagate(False)
        right.pack_propagate(False)

        self._build_left(left)
        self._build_mid(mid)
        self._build_right(right)

    # ── LEFT ─────────────────────────────────────────────────────────────────
    def _build_left(self, p):
        rc = card(p, "  RPM SETPOINT", BLUE)
        rf = tk.Frame(rc, bg=CARD)
        rf.pack(fill=tk.X, padx=14, pady=(0, 6))
        tk.Label(rf, text="Target Speed (RPM)", bg=CARD, fg=SLATE2,
                 font=(FU, 11)).pack(anchor="w")
        self._rpm_sp_e = ctk.CTkEntry(rf, width=202, height=42,
                     fg_color=BG, text_color=SLATE,
                     border_color=BLUE, border_width=2,
                     font=(FM, 16, "bold"))
        self._rpm_sp_e.insert(0, "1440")
        self._rpm_sp_e.pack(fill=tk.X, pady=(4, 8))
        abtn(rf, "  ▶  APPLY RPM", BLUE, self._set_rpm, width=202, height=40
             ).pack(fill=tk.X)
        self._freq_lbl = tk.Label(rf, text="Frequency:  — Hz",
                                  bg=CARD, fg=SLATE2, font=(FU, 10))
        self._freq_lbl.pack(anchor="w", pady=(6, 8))

        bc = card(p, "  MOTOR CONTROL", TEAL)
        for txt, col, cmd in [
            ("▶▶  FORWARD",  TEAL,   self._fwd),
            ("◀◀  REVERSE",  PURPLE, self._rev),
            ("■   STOP",     ORANGE, self._stop),
            ("⚡  E-STOP",   RED,    self._estop),
        ]:
            abtn(bc, txt, col, cmd, width=202, height=44
                 ).pack(padx=14, pady=4, fill=tk.X)

        abtn(bc, "↺  RESET FAULT  (clears CE)", SLATE2, self._reset_fault,
             width=202, height=36).pack(padx=14, pady=(2, 10), fill=tk.X)

        dc = card(p, "  MOTOR STATUS", SLATE2)
        self._dir_cv = tk.Canvas(dc, width=202, height=58,
                                 bg=CARD, highlightthickness=0)
        self._dir_cv.pack(padx=14, pady=(0, 12))
        self._draw_dir("STOPPED")

        oc = card(p, "  OVERCURRENT PROTECTION", ORANGE)
        of = tk.Frame(oc, bg=CARD)
        of.pack(fill=tk.X, padx=14, pady=(0, 4))
        tk.Label(of, text="Threshold (A)", bg=CARD, fg=SLATE2,
                 font=(FU, 11)).pack(anchor="w")
        self._oc_thr_e = ctk.CTkEntry(of, width=202, height=40,
                     fg_color=BG, text_color=SLATE,
                     border_color=ORANGE, border_width=2,
                     font=(FM, 15, "bold"))
        self._oc_thr_e.insert(0, "5.0")
        self._oc_thr_e.pack(fill=tk.X, pady=(4, 8))
        abtn(of, "  ✔  SET THRESHOLD", ORANGE, self._apply_oc,
             width=202, height=38).pack(fill=tk.X)
        orw = tk.Frame(oc, bg=CARD)
        orw.pack(fill=tk.X, padx=14, pady=(6, 10))
        self._oc_dot = PulseDot(orw, color=TEAL, sz=16, bg=CARD)
        self._oc_dot.pack(side=tk.LEFT, padx=(0, 8))
        self._oc_lbl = tk.Label(orw, text="PROTECTION OK",
                                bg=CARD, fg=TEAL, font=(FU, 12, "bold"))
        self._oc_lbl.pack(side=tk.LEFT)

    def _draw_dir(self, state):
        c = self._dir_cv
        c.delete("all")
        col  = {"FORWARD": TEAL, "REVERSE": PURPLE,
                "STOPPED": SLATE2, "E-STOP": RED}.get(state, SLATE2)
        icon = {"FORWARD": "▶▶", "REVERSE": "◀◀",
                "STOPPED": "■",  "E-STOP": "⚡"}.get(state, "—")
        tint = ArcGauge._tint(col, 0.12)
        c.create_rectangle(2, 2, 200, 56, fill=tint, outline=col, width=2)
        c.create_text(101, 29, text=f"{icon}   {state}", fill=col,
                      font=(FU, 14, "bold"))

    # ── MIDDLE ────────────────────────────────────────────────────────────────
    def _build_mid(self, p):
        gf = tk.Frame(p, bg=CARD)
        gf.pack(fill=tk.X, pady=(0, 10))
        tk.Frame(gf, bg=BLUE, height=4).pack(fill=tk.X)
        gr = tk.Frame(gf, bg=CARD)
        gr.pack(fill=tk.X, pady=8)

        self.g_rpm_vfd  = ArcGauge(gr, label="SPEED (VFD)",  unit="RPM",
                                    vmin=0, vmax=1800, color=BLUE_G, sz=208)
        self.g_rpm_prox = ArcGauge(gr, label="SPEED (PROX)", unit="RPM",
                                    vmin=0, vmax=1800, color=PURPLE, sz=208)
        self.g_curr     = ArcGauge(gr, label="CURRENT",      unit="A",
                                    vmin=0, vmax=10,   color=ORANGE, sz=208)
        self.g_volt     = ArcGauge(gr, label="VOLTAGE",      unit="V",
                                    vmin=0, vmax=500,  color=TEAL,   sz=208)
        self.g_pf       = ArcGauge(gr, label="POWER FACTOR", unit="",
                                    vmin=0, vmax=1.0,  color=PURPLE, sz=208)

        for g in (self.g_rpm_vfd, self.g_rpm_prox,
                  self.g_curr, self.g_volt, self.g_pf):
            g.pack(side=tk.LEFT, padx=4, pady=6, expand=True)

        ch = card(p, "  MOTOR CHARACTERISTICS  (N-T  &  T-I  Curves)",
                  BLUE, fill=True, expand=True)
        ir = tk.Frame(ch, bg=CARD)
        ir.pack(fill=tk.X, padx=14, pady=(0, 6))
        tk.Label(ir, text="S₁ (kg):", bg=CARD, fg=SLATE2,
                 font=(FU, 12)).pack(side=tk.LEFT, padx=(0, 4))
        self._s1_e = ctk.CTkEntry(ir, width=72, height=34,
                         fg_color=BG, text_color=SLATE,
                         border_color=BORDER2, border_width=2,
                         font=(FM, 13, "bold"))
        self._s1_e.insert(0, "3.0")
        self._s1_e.pack(side=tk.LEFT, padx=(0, 12))
        tk.Label(ir, text="S₂ (kg):", bg=CARD, fg=SLATE2,
                 font=(FU, 12)).pack(side=tk.LEFT, padx=(0, 4))
        self._s2_e = ctk.CTkEntry(ir, width=72, height=34,
                         fg_color=BG, text_color=SLATE,
                         border_color=BORDER2, border_width=2,
                         font=(FM, 13, "bold"))
        self._s2_e.insert(0, "1.0")
        self._s2_e.pack(side=tk.LEFT, padx=(0, 12))
        abtn(ir, "➕ Add Point", BLUE, self._add_point, width=120, height=34
             ).pack(side=tk.LEFT, padx=4)
        abtn(ir, "🗑 Clear", RED, self._clear_char, width=100, height=34
             ).pack(side=tk.LEFT, padx=4)

        self.fig = Figure(figsize=(8, 3.2), facecolor=CARD)
        self.fig.subplots_adjust(left=0.08, right=0.97, top=0.85,
                                 bottom=0.18, wspace=0.3)
        self.ax_nt = self.fig.add_subplot(121)
        self.ax_ti = self.fig.add_subplot(122)
        self._sax(self.ax_nt, "Speed – Torque  (N-T)",   "Torque (Nm)", "Speed (RPM)", BLUE_G)
        self._sax(self.ax_ti, "Torque – Current  (T-I)", "Current (A)", "Torque (Nm)", ORANGE)

        self.canvas_mpl = FigureCanvasTkAgg(self.fig, master=ch)
        self.canvas_mpl.get_tk_widget().pack(fill=tk.BOTH, expand=True,
                                              padx=8, pady=(0, 8))
        self.canvas_mpl.draw()

    def _sax(self, ax, title, xl, yl, accent):
        ax.set_facecolor(BG)
        ax.set_title(title, color=accent, fontsize=11, fontweight="bold", pad=6)
        ax.set_xlabel(xl, color=SLATE2, fontsize=10)
        ax.set_ylabel(yl, color=SLATE2, fontsize=10)
        ax.tick_params(colors=SLATE2, labelsize=9)
        for sp in ax.spines.values():
            sp.set_color(BORDER2)
        ax.grid(color=BORDER, linewidth=0.7, linestyle="--", alpha=0.8)

    # ── RIGHT ─────────────────────────────────────────────────────────────────
    def _build_right(self, p):
        mc = card(p, "  LIVE READINGS", BLUE)
        self.m = {}
        for lbl, unit, col, dec, key in [
            ("Input Voltage",    "V",   TEAL,   1, "inp_volt"),
            ("Output Voltage",   "V",   BLUE,   1, "volt"),
            ("Current (VFD)",    "A",   ORANGE, 2, "curr"),
            ("Active Power",     "W",   TEAL,   1, "pow"),
            ("Supply Frequency", "Hz",  BLUE,   1, "freq"),
            ("Power Factor",     "",    PURPLE, 2, "pf"),
            ("VFD Output Freq",  "Hz",  BLUE_G, 2, "vfd_freq"),
            ("VFD Output Volt",  "V",   TEAL,   1, "vfd_volt"),
            ("VFD Output Curr",  "A",   ORANGE, 2, "vfd_curr"),
            ("Motor RPM (VFD)",  "RPM", BLUE_G, 0, "rpm_vfd"),
            ("Motor RPM (PROX)", "RPM", PURPLE, 0, "rpm_prox"),
            ("Setpoint Freq",    "Hz",  SLATE2, 2, "setf"),
        ]:
            row = MetricRow(mc, lbl, unit, color=col, decimals=dec)
            row.pack(fill=tk.X)
            self.m[key] = row
        tk.Frame(mc, bg=CARD, height=6).pack()

        ph = card(p, "  THREE-PHASE VOLTAGES", TEAL)
        self.m3 = {}
        for name, col in [("Phase  R", RED), ("Phase  Y", ORANGE), ("Phase  B", BLUE)]:
            row = MetricRow(ph, name, "V", color=col, decimals=1)
            row.pack(fill=tk.X)
            self.m3[name] = row
        tk.Frame(ph, bg=CARD, height=4).pack()

        lc = card(p, "  SYSTEM LOG", SLATE2, fill=True, expand=True)
        self._log_box = tk.Text(lc, bg=BG, fg=SLATE, font=(FM, 10),
                                bd=0, wrap=tk.WORD, state=tk.DISABLED,
                                insertbackground=SLATE, selectbackground=BLUE_L,
                                relief=tk.FLAT, padx=8, pady=6)
        sb = tk.Scrollbar(lc, command=self._log_box.yview, bg=BG, troughcolor=BG)
        self._log_box.configure(yscrollcommand=sb.set)
        sb.pack(side=tk.RIGHT, fill=tk.Y, padx=(0, 6), pady=6)
        self._log_box.pack(fill=tk.BOTH, expand=True, padx=(10, 0), pady=(0, 10))

    # ─────────────────────────────────────────────────────────────────────────
    # CONTROL ACTIONS
    # ─────────────────────────────────────────────────────────────────────────
    def _guard(self):
        if self.vfd is None or not self.vfd.ok:
            messagebox.showerror("Not Connected",
                                 "VFD is not connected.\n"
                                 "Use Re-Scan or restart the app.")
            return False
        return True

    def _get_hz(self):
        """Read RPM entry and return target Hz, or None on invalid input."""
        try:
            rpm = _fget_e(self._rpm_sp_e, 1440.0)
            if not 1 <= rpm <= 3000:
                messagebox.showwarning("RPM Range", "Enter 1 – 3000 RPM.")
                return None
            return self.vfd.rpm_to_hz(rpm)
        except ValueError:
            messagebox.showerror("Input", "Enter a valid number.")
            return None

    def _set_rpm(self):
        """Apply new frequency while motor is already running."""
        if not self._guard(): return
        hz = self._get_hz()
        if hz is None: return
        ok = self.vfd.set_frequency(hz)
        if ok:
            self._freq_lbl.configure(text=f"Frequency:  {hz:.2f} Hz")
            self.m["setf"].set_value(hz)
            self._log(f"Freq setpoint → {hz:.2f} Hz")
        else:
            if not self.running:
                self._log("Freq write skipped while stopped — will apply on FORWARD/REVERSE")
            else:
                self._log(f"Freq write failed: {self.vfd.err}")

    def _fwd(self):
        if not self._guard(): return
        hz = self._get_hz()
        if hz is None: return
        # Use func-10H to send RUN + FREQ atomically in one frame (GD200A manual §9.4.8.3)
        ok = self.vfd.run_at_freq(hz)
        if ok:
            self.running = True
            self._draw_dir("FORWARD")
            self._freq_lbl.configure(text=f"Frequency:  {hz:.2f} Hz")
            self.m["setf"].set_value(hz)
            self._log(f"FORWARD @ {hz:.2f} Hz sent to GD200A")
        else:
            self._draw_dir("STOPPED")
            self._log(f"Forward FAILED: {self.vfd.err}")
            messagebox.showerror(
                "Motor Did Not Start",
                "VFD did not respond to FORWARD command.\n\n"
                "Most likely causes:\n"
                "1.  CE fault active → click  ↺ RESET FAULT  first\n"
                "2.  P14.04 ≠ 0.0  (set to 0.0 to disable CE timeout)\n"
                "3.  P00.01 ≠ 2    (must be  2  for Modbus control)\n"
                "4.  P00.06 ≠ 8    (must be  8  for Modbus frequency)\n"
                "5.  RS-485 A+/B- swapped — try swapping the two wires\n"
                "6.  Wrong COM port selected"
            )

    def _rev(self):
        if not self._guard(): return
        hz = self._get_hz()
        if hz is None: return
        ok = self.vfd.run_reverse_at_freq(hz)
        if ok:
            self.running = True
            self._draw_dir("REVERSE")
            self._freq_lbl.configure(text=f"Frequency:  {hz:.2f} Hz")
            self.m["setf"].set_value(hz)
            self._log(f"REVERSE @ {hz:.2f} Hz sent to GD200A")
        else:
            self._log(f"Reverse FAILED: {self.vfd.err}")

    def _stop(self):
        if not self._guard(): return
        self.vfd.stop()
        self.running = False
        self._draw_dir("STOPPED")
        self._log("CMD 0x0005 → STOP sent to GD200A")

    def _estop(self):
        if self.vfd and self.vfd.ok:
            self.vfd.coast_stop()
        self.running = False
        self._draw_dir("E-STOP")
        self._oc_dot.set_state(True, color=RED)
        self._oc_lbl.configure(text="⚡ E-STOP ACTIVE", fg=RED)
        self._log("CMD 0x0006 → E-STOP (coast) sent")
        messagebox.showwarning("E-STOP", "Emergency stop activated!")

    def _reset_fault(self):
        if not self._guard(): return
        ok = self.vfd.reset_fault()
        if ok:
            self._draw_dir("STOPPED")
            self._oc_dot.set_state(True, color=TEAL)
            self._oc_lbl.configure(text="PROTECTION OK", fg=TEAL)
            self._log("CMD 0x0007 → FAULT RESET sent — CE cleared")
            messagebox.showinfo("Fault Reset",
                                "VFD fault reset command sent.\n"
                                "CE fault should now be cleared.\n"
                                "You can start the motor.")
        else:
            self._log(f"Fault reset failed: {self.vfd.err}")
            messagebox.showerror("Reset Failed",
                                 "Could not reach VFD.\n"
                                 "Check RS-485 wiring and COM port.")

    def _apply_oc(self):
        try:
            t = _fget_e(self._oc_thr_e, 5.0)
            if t <= 0: raise ValueError
            self._log(f"OC threshold → {t:.2f} A")
            messagebox.showinfo("OC Set", f"Overcurrent threshold = {t:.2f} A")
        except ValueError:
            messagebox.showerror("Invalid", "Enter a positive value.")

    # ─────────────────────────────────────────────────────────────────────────
    # CHARACTERISTICS
    # ─────────────────────────────────────────────────────────────────────────
    def _add_point(self):
        try:
            s1, s2 = _fget_e(self._s1_e, 3.0), _fget_e(self._s2_e, 1.0)
            torque  = (s1 - s2) * 1.5
            rpm_val = self.rpm_vfd_val
            curr    = self.current
            self.c_spd.append(rpm_val)
            self.c_trq.append(torque)
            self.c_cur.append(curr)
            self._redraw_char()
            self._log(f"Point: {rpm_val:.0f} RPM | {torque:.2f} Nm | {curr:.2f} A")
        except Exception as e:
            messagebox.showerror("Error", str(e))

    def _clear_char(self):
        self.c_spd.clear()
        self.c_trq.clear()
        self.c_cur.clear()
        self._redraw_char()
        self._log("Characteristic data cleared")

    def _redraw_char(self):
        self.ax_nt.cla()
        self.ax_ti.cla()
        self._sax(self.ax_nt, "Speed – Torque  (N-T)",   "Torque (Nm)", "Speed (RPM)", BLUE_G)
        self._sax(self.ax_ti, "Torque – Current  (T-I)", "Current (A)", "Torque (Nm)", ORANGE)
        if self.c_trq:
            self.ax_nt.plot(self.c_trq, self.c_spd, "o-",
                            color=BLUE_G, lw=2.5, ms=8,
                            markerfacecolor=CARD, markeredgecolor=BLUE_G,
                            markeredgewidth=2.5)
            self.ax_nt.fill_between(self.c_trq, self.c_spd,
                                    alpha=0.10, color=BLUE_G)
            self.ax_ti.plot(self.c_cur, self.c_trq, "s-",
                            color=ORANGE, lw=2.5, ms=8,
                            markerfacecolor=CARD, markeredgecolor=ORANGE,
                            markeredgewidth=2.5)
            self.ax_ti.fill_between(self.c_cur, self.c_trq,
                                    alpha=0.10, color=ORANGE)
        self.fig.canvas.draw_idle()

    # ─────────────────────────────────────────────────────────────────────────
    # POLLING
    #
    # FIX: P17 registers (0x1100-0x1105) return exception code 6 (busy) when
    # the motor is stopped — this is normal GD200A behaviour, not an error.
    # The poll handler now distinguishes between:
    #   • Motor stopped  → show zeros silently (no ERR, no log spam)
    #   • Motor running  → show ERR only if data vanishes unexpectedly
    # ─────────────────────────────────────────────────────────────────────────
    def _poll_thread(self):
        while not self.stop_polling:
            self._do_poll()
            time.sleep(5)  # Poll every 5 seconds

    def _do_poll(self):
        if self.pzem and self.pzem.ok:
            d = self.pzem.read_all()
            if d:
                freq = d["freq"]
                if freq != self._prev_freq:
                    self.update_queue.put(('set_metric', 'freq', freq))
                    self._prev_freq = freq

        # ── GD200A monitor registers ──────────────────────────────────────────
        if self.vfd and self.vfd.ok:
            mon = self.vfd.read_monitor()
            if mon:
                src = mon.get("source", "P17")
                rpm_vfd = mon["motor_rpm"]
                if rpm_vfd != self._prev_rpm_vfd:
                    self.update_queue.put(('set_gauge', 'g_rpm_vfd', rpm_vfd))
                    self.update_queue.put(('set_metric', 'rpm_vfd', rpm_vfd))
                    self._prev_rpm_vfd = rpm_vfd
                    self.rpm_vfd_val = rpm_vfd
                vfd_freq = mon["out_freq"]
                if vfd_freq != self._prev_vfd_freq:
                    self.update_queue.put(('set_metric', 'vfd_freq', vfd_freq))
                    self._prev_vfd_freq = vfd_freq
                vfd_volt = mon["out_volt"]
                if vfd_volt != self._prev_vfd_volt:
                    self.update_queue.put(('set_metric', 'vfd_volt', vfd_volt))
                    self._prev_vfd_volt = vfd_volt
                vfd_curr = mon["out_curr"]
                if vfd_curr != self._prev_vfd_curr:
                    self.update_queue.put(('set_metric', 'vfd_curr', vfd_curr))
                    self._prev_vfd_curr = vfd_curr
                set_freq = mon["set_freq"]
                if set_freq != self._prev_set_freq:
                    self.update_queue.put(('set_metric', 'setf', set_freq))
                    self._prev_set_freq = set_freq

                # ── Voltage & Power from VFD (replaces PZEM) ─────────────────
                pwr = self.vfd.read_power(mon)
                v   = pwr["voltage"]     # VFD output voltage
                i   = pwr["current"]
                pf  = pwr["pf"]
                pw  = pwr["power"]

                # ── Input (supply) voltage from DC bus register 0x110B ────────
                v_in = self.vfd.read_input_voltage() / 10.0
                if v_in > 0:
                    if v_in != self._prev_inp_volt:
                        self.update_queue.put(('set_metric', 'inp_volt', v_in))
                        self._prev_inp_volt = v_in
                else:
                    # Motor stopped → P17.11 returns exception 6, hold last value
                    pass

                if v_in != self._prev_inp_volt:
                    self.update_queue.put(('set_gauge', 'g_volt', v_in))
                    self._prev_inp_volt = v_in
                if i != self._prev_current:
                    self.update_queue.put(('set_gauge', 'g_curr', i))
                    self._prev_current = i
                if pf != self._prev_pf:
                    self.update_queue.put(('set_gauge', 'g_pf', pf))
                    self._prev_pf = pf
                warn = i > _fget_e(self._oc_thr_e, 5.0)
                if v != self._prev_voltage:
                    self.update_queue.put(('set_metric', 'volt', v))
                    self._prev_voltage = v
                if i != self._prev_current:
                    self.update_queue.put(('set_metric_warn', 'curr', i, warn))
                    self._prev_current = i
                    self.current = i
                if pw != self._prev_power:
                    self.update_queue.put(('set_metric', 'pow', pw))
                    self._prev_power = pw
                if pf != self._prev_pf:
                    self.update_queue.put(('set_metric', 'pf', pf))
                    self._prev_pf = pf

                # ── Three-phase voltages = VFD output voltage (balanced) ──────
                # VFD generates balanced 3-phase output — all phases equal.
                for ph in ("Phase  R", "Phase  Y", "Phase  B"):
                    self.update_queue.put(('set_m3', ph, v))
                self.update_queue.put(('check_oc', i))

                # If we're on base-block fallback and motor is stopped,
                # show "stopped" label instead of bare 0 for rpm/curr
                if src == "base" and not self.running:
                    self.update_queue.put(('set_metric_text', 'rpm_vfd', "0 (stopped)", SLATE3))
                    self.update_queue.put(('set_metric_text', 'vfd_curr', "0.00 (stopped)", SLATE3))
            else:
                # Both P17 and base-block failed — genuine comms problem
                if self.running:
                    self.update_queue.put(('set_gauge_na', 'g_rpm_vfd'))
                    self.update_queue.put(('set_metric_text', 'rpm_vfd', "ERR", RED))
                    self.update_queue.put(('log', "Monitor read failed while running — possible CE fault"))
                else:
                    self.update_queue.put(('set_gauge', 'g_rpm_vfd', 0))
                    self.update_queue.put(('set_metric', 'rpm_vfd', 0))

            # ── Proximity sensor — register 0x3010 (HDI hardware frequency) ───
            # Unit = 0.01 Hz per count. RPM = (raw÷100) × 60.
            # Confirmed: raw=334 at 200 RPM → 3.34 Hz → 200.4 RPM ✓
            rpm_prox, freq_hz = self.vfd.read_hdi_freq_rpm(pulses_per_rev=1)
            self._prox_seen = True
            self._prox_rpm  = rpm_prox
            if rpm_prox != self._prev_rpm_prox:
                self.update_queue.put(('set_gauge', 'g_rpm_prox', self._prox_rpm))
                self.update_queue.put(('set_metric', 'rpm_prox', self._prox_rpm))
                self._prev_rpm_prox = rpm_prox
            self.update_queue.put(('set_prox_status', rpm_prox, freq_hz))

    def _process_updates(self):
        try:
            while True:
                update = self.update_queue.get_nowait()
                self._apply_update(update)
        except queue.Empty:
            pass
        self.after(100, self._process_updates)

    def _apply_update(self, update):
        cmd = update[0]
        if cmd == 'set_gauge':
            _, gauge, value = update
            getattr(self, gauge).set_value(value)
        elif cmd == 'set_gauge_na':
            _, gauge = update
            getattr(self, gauge).set_na()
        elif cmd == 'set_metric':
            _, key, value = update
            self.m[key].set_value(value)
        elif cmd == 'set_metric_warn':
            _, key, value, warn = update
            self.m[key].set_value(value, warn=warn)
        elif cmd == 'set_metric_text':
            _, key, text, color = update
            self.m[key].set_text(text, color=color)
        elif cmd == 'set_m3':
            _, ph, value = update
            self.m3[ph].set_value(value)
        elif cmd == 'check_oc':
            _, curr = update
            self._check_oc(curr)
        elif cmd == 'set_prox_status':
            _, rpm_prox, freq_hz = update
            if rpm_prox > 0:
                self._prox_dot.set_state(True, color=TEAL)
                self._prox_lbl.configure(
                    text=f"PROX  {rpm_prox:.0f} RPM  ({freq_hz:.2f} Hz)",
                    fg=TEAL)
            else:
                self._prox_dot.set_state(True, color=BLUE_G)
                self._prox_lbl.configure(text="PROX  READY  (0 RPM)", fg=BLUE_G)
        elif cmd == 'log':
            _, msg = update
            self._log(msg)

    def _check_oc(self, curr):
        thr = _fget_e(self._oc_thr_e, 5.0)
        if curr > thr:
            if not self.oc_trip_t:
                self.oc_trip_t = time.time()
                self._oc_dot.set_state(True, color=ORANGE)
                self._oc_lbl.configure(text=f"⚠  WARNING  {curr:.2f} A", fg=ORANGE)
            elif (time.time() - self.oc_trip_t) >= 1.0:
                self._estop()
                self._oc_lbl.configure(text=f"🔴  OC TRIP  {curr:.2f} A", fg=RED)
        else:
            self.oc_trip_t = None
            self._oc_dot.set_state(True, color=TEAL)
            self._oc_lbl.configure(text="PROTECTION OK", fg=TEAL)

    # ─────────────────────────────────────────────────────────────────────────
    # LOG
    # ─────────────────────────────────────────────────────────────────────────
    def _log(self, msg):
        ts = time.strftime("%H:%M:%S")
        self._log_box.configure(state=tk.NORMAL)
        self._log_box.insert(tk.END, f"[{ts}]  {msg}\n")
        self._log_box.see(tk.END)
        self._log_box.configure(state=tk.DISABLED)

    # ─────────────────────────────────────────────────────────────────────────
    # CLOSE
    # ─────────────────────────────────────────────────────────────────────────
    def on_close(self):
        self.stop_polling = True
        if self.polling_thread and self.polling_thread.is_alive():
            self.polling_thread.join(timeout=1)
        if self.vfd:
            try:
                self.vfd.stop()
            except Exception:
                pass
            self.vfd.disconnect()
        if self.pzem:
            self.pzem.disconnect()
        self.destroy()


# ═════════════════════════════════════════════════════════════════════════════
if __name__ == "__main__":
    app = MotorDashboard()
    app.protocol("WM_DELETE_WINDOW", app.on_close)
    app.mainloop()