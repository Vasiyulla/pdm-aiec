"""Custom tkinter widgets used in the dashboard."""
import tkinter as tk
import customtkinter as ctk
import math

from config import BG, CARD, BORDER, BORDER2, BLUE, BLUE_G, RED, SLATE, SLATE2, SLATE3, FM, FU, TEAL


class ArcGauge(tk.Canvas):
    START = 210
    SWEEP = 300

    def __init__(self, parent, *, label, unit, vmin, vmax, color=BLUE_G, sz=200):
        super().__init__(parent, width=sz, height=sz,
                         bg=CARD, highlightthickness=0)
        self.label = label
        self.unit  = unit
        self.vmin  = float(vmin)
        self.vmax  = float(vmax)
        self.color = color
        self.sz    = sz
        self.cx = self.cy = sz / 2
        self.R  = sz / 2 - 22
        self.TW = 18
        self._cur = float(vmin)
        self._tgt = float(vmin)
        self._na  = False

        self._draw_static()
        self._redraw()
        self.after(64, self._animate)

    def _draw_static(self):
        m = 22 + self.TW // 2
        self.create_arc(m-1, m+2, self.sz-m+1, self.sz-m+4,
                        start=self.START, extent=-self.SWEEP,
                        style=tk.ARC, outline="#c8d4e0", width=self.TW+4, tags="st")
        self.create_arc(m, m, self.sz-m, self.sz-m,
                        start=self.START, extent=-self.SWEEP,
                        style=tk.ARC, outline=BORDER, width=self.TW, tags="st")
        for i in range(11):
            f = i / 10.0
            a  = math.radians(self.START - f * self.SWEEP)
            r1 = self.R + 4
            r2 = self.R - (8 if i % 5 == 0 else 3)
            self.create_line(
                self.cx + r1*math.cos(a), self.cy - r1*math.sin(a),
                self.cx + r2*math.cos(a), self.cy - r2*math.sin(a),
                fill=SLATE3 if i % 5 == 0 else BORDER, width=1, tags="st")
        for frac, val in [(0.0, self.vmin), (1.0, self.vmax)]:
            a  = math.radians(self.START - frac * self.SWEEP)
            rx = self.cx + (self.R + 14) * math.cos(a)
            ry = self.cy - (self.R + 14) * math.sin(a)
            self.create_text(rx, ry, text=f"{int(val)}",
                             fill=SLATE3, font=(FM, 7), tags="st")
        self.create_text(self.cx, self.cy + self.R * 0.52,
                         text=self.label, fill=SLATE2,
                         font=(FU, 10, "bold"), tags="st")

    def _redraw(self):
        self.delete("dyn")
        m  = 22 + self.TW // 2
        cr = self.R * 0.56

        if self._na:
            self.create_oval(self.cx-cr, self.cy-cr, self.cx+cr, self.cy+cr,
                             fill=CARD, outline=BORDER, width=1, tags="dyn")
            self.create_text(self.cx, self.cy - 10,
                             text="N/A", fill=SLATE3,
                             font=(FM, int(self.sz*0.11), "bold"), tags="dyn")
            self.create_text(self.cx, self.cy + 12,
                             text=self.unit, fill=SLATE3,
                             font=(FM, 9, "bold"), tags="dyn")
            return

        pct    = (self._cur - self.vmin) / (self.vmax - self.vmin)
        pct    = max(0.0, min(1.0, pct))
        extent = pct * self.SWEEP

        if extent > 0.5:
            gc = self._tint(self.color, 0.22)
            self.create_arc(m-4, m-4, self.sz-m+4, self.sz-m+4,
                            start=self.START, extent=-extent,
                            style=tk.ARC, outline=gc,
                            width=self.TW+8, tags="dyn")
            self.create_arc(m, m, self.sz-m, self.sz-m,
                            start=self.START, extent=-extent,
                            style=tk.ARC, outline=self.color,
                            width=self.TW, tags="dyn")
            tip = math.radians(self.START - extent)
            tx  = self.cx + self.R * math.cos(tip)
            ty  = self.cy - self.R * math.sin(tip)
            tcr = self.TW // 2
            self.create_oval(tx-tcr-3, ty-tcr-3, tx+tcr+3, ty+tcr+3,
                             fill=gc, outline="", tags="dyn")
            self.create_oval(tx-tcr+1, ty-tcr+1, tx+tcr-1, ty+tcr-1,
                             fill=self.color, outline="", tags="dyn")

        self.create_oval(self.cx-cr, self.cy-cr, self.cx+cr, self.cy+cr,
                         fill=CARD, outline=BORDER, width=1, tags="dyn")
        fmt = f"{self._cur:.0f}" if self.vmax >= 100 else f"{self._cur:.2f}"
        self.create_text(self.cx, self.cy - 14, text=fmt, fill=SLATE,
                         font=(FM, int(self.sz * 0.14), "bold"), tags="dyn")
        self.create_text(self.cx, self.cy + 10, text=self.unit, fill=self.color,
                         font=(FM, 10, "bold"), tags="dyn")

    def _animate(self):
        d = self._tgt - self._cur
        if abs(d) > 0.05:
            self._cur += d * 0.13
            self._redraw()
        elif self._cur != self._tgt:
            self._cur = self._tgt
            self._redraw()
        self.after(16, self._animate)

    def set_value(self, v):
        self._na  = False
        self._tgt = max(self.vmin, min(self.vmax, float(v)))

    def set_na(self):
        self._na = True
        self._redraw()

    @staticmethod
    def _tint(hx, alpha):
        h = hx.lstrip("#")
        r,g,b = int(h[0:2],16), int(h[2:4],16), int(h[4:6],16)
        return "#{:02x}{:02x}{:02x}".format(
            int(r+(255-r)*(1-alpha)),
            int(g+(255-g)*(1-alpha)),
            int(b+(255-b)*(1-alpha)))


class PulseDot(tk.Canvas):
    def __init__(self, parent, color=TEAL, sz=16, bg=CARD, **kw):
        super().__init__(parent, width=sz, height=sz,
                         bg=bg, highlightthickness=0, **kw)
        self.color = color
        self.sz    = sz
        self._on   = True
        self._ph   = 0.0
        self._tick()

    def _tick(self):
        self.delete("all")
        r = self.sz / 2
        if self._on:
            a = (math.sin(self._ph) + 1) / 2
            self.create_oval(0, 0, self.sz, self.sz,
                             fill=self._blend(self.color, self["bg"], 0.25+a*0.25),
                             outline="")
            ir = r - 3
            self.create_oval(r-ir, r-ir, r+ir, r+ir,
                             fill=self._blend(self.color, "#ffffff", 0.3+a*0.2),
                             outline="")
            self._ph += 0.10
        else:
            ir = r - 3
            self.create_oval(r-ir, r-ir, r+ir, r+ir, fill=BORDER, outline="")
        self.after(100, self._tick)

    def set_state(self, on, color=None):
        self._on = on
        if color:
            self.color = color

    @staticmethod
    def _blend(c1, c2, t):
        def p(h):
            h = h.lstrip("#")
            return int(h[:2],16), int(h[2:4],16), int(h[4:6],16)
        r1,g1,b1 = p(c1);  r2,g2,b2 = p(c2)
        return "#{:02x}{:02x}{:02x}".format(
            int(g2+(g1-g2)*t), int(b2+(b1-b2)*t), int(b2+(b1-b2)*t))


class MetricRow(tk.Frame):
    def __init__(self, parent, label, unit, color=BLUE, decimals=1, **kw):
        super().__init__(parent, bg=CARD, **kw)
        self.decimals = decimals
        self._cur = 0.0
        self._tgt = 0.0
        self._warn = False

        tk.Frame(self, bg=BORDER, height=1).pack(fill=tk.X)
        row = tk.Frame(self, bg=CARD)
        row.pack(fill=tk.X, padx=14, pady=7)
        tk.Label(row, text=label, bg=CARD, fg=SLATE2,
                 font=(FU, 12), anchor="w").pack(side=tk.LEFT, fill=tk.X, expand=True)
        self._val = tk.Label(row, text="—", bg=CARD, fg=SLATE,
                 font=(FM, 13, "bold"))
        self._val.pack(side=tk.LEFT)
        tk.Label(row, text=f"  {unit}", bg=CARD, fg=color,
                 font=(FU, 11, "bold"), width=5, anchor="w").pack(side=tk.LEFT)
        self._animate()

    def _animate(self):
        d = self._tgt - self._cur
        if abs(d) > 10**(-self.decimals - 1):
            self._cur += d * 0.16
            self._val.configure(
                text=f"{self._cur:.{self.decimals}f}",
                fg=RED if self._warn else SLATE)
        self.after(80, self._animate)

    def set_value(self, v, warn=False):
        self._tgt  = float(v)
        self._warn = warn

    def set_text(self, s, color=SLATE3):
        self._val.configure(text=s, fg=color)


# helpers

def card(parent, title, accent=BLUE, fill=False, expand=False):
    outer = tk.Frame(parent, bg=BG)
    outer.pack(fill=tk.BOTH if fill else tk.X, expand=expand, pady=(0, 10))
    tk.Frame(outer, bg=BORDER2).place(relx=0, rely=0, relwidth=1, relheight=1, x=3, y=3)
    inner = tk.Frame(outer, bg=CARD)
    inner.pack(fill=tk.BOTH, expand=True)
    tk.Frame(inner, bg=accent, height=4).pack(fill=tk.X)
    tk.Label(inner, text=title, bg=CARD, fg=accent,
             font=(FU, 12, "bold"), anchor="w", padx=14, pady=8).pack(fill=tk.X)
    return inner


def abtn(parent, text, color, cmd, width=190, height=42):
    tint = ArcGauge._tint(color, 0.15)
    b = ctk.CTkButton(parent, text=text,
                      fg_color=tint, hover_color=ArcGauge._tint(color, 0.35),
                      text_color=color, border_color=color, border_width=2,
                      corner_radius=8, font=(FU, 13, "bold"),
                      width=width, height=height, command=cmd)
    b.bind("<ButtonPress-1>",   lambda e: b.configure(fg_color=color, text_color="#fff"))
    b.bind("<ButtonRelease-1>", lambda e: b.configure(fg_color=tint,  text_color=color))
    return b


def _fget_e(entry, default=0.0):
    """Safely read a CTkEntry widget value as float.

    Returns ``default`` if the widget is empty or contains invalid text.
    """
    try:
        v = entry.get().strip()
        return float(v) if v else default
    except (tk.TclError, ValueError, AttributeError):
        return default
