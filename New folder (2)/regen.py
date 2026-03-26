import pathlib
path = pathlib.Path('motor_control.py')
text = path.read_text(encoding='utf-8').splitlines()
# find end of header docstring
end = 0
for i, line in enumerate(text):
    if line.strip().endswith('"""') and i > 0:
        end = i
        break
header = text[:end+1]
# find main dashboard start
dash = 0
for i, line in enumerate(text):
    if 'MAIN DASHBOARD' in line:
        dash = i
        break
body = text[dash:]
# build new content
new = []
new.extend(header)
new.extend(['', 'import tkinter as tk', 'import customtkinter as ctk',
            'from tkinter import messagebox, ttk',
            'import threading, time, math, platform', '',
            'import matplotlib', 'matplotlib.use("TkAgg")',
            'from matplotlib.backends.backend_tkagg import FigureCanvasTkAgg',
            'from matplotlib.figure import Figure', '',
            'ctk.set_appearance_mode("light")',
            'ctk.set_default_color_theme("blue")', '',
            'from config import *',
            'from serial_utils import list_serial_ports, auto_detect_devices',
            'from vfd import GD200A',
            'from pzem import PZEM004T',
            'from widgets import ArcGauge, PulseDot, MetricRow, card, abtn, _fget_e',
            'from dialogs import PortDialog, DiagDialog', '',])
new.extend(body)
path.write_text("\n".join(new), encoding='utf-8')
print('rewritten file length', len(new))