# ⚡ Motor Dashboard — Predictive Maintenance System

<div align="center">

![Motor Dashboard Banner](https://img.shields.io/badge/Motor%20Dashboard-Predictive%20Maintenance-0EA5E9?style=for-the-badge&logo=flutter&logoColor=white)

[![Flutter](https://img.shields.io/badge/Flutter-3.38+-02569B?style=flat-square&logo=flutter)](https://flutter.dev)
[![FastAPI](https://img.shields.io/badge/FastAPI-0.100+-009688?style=flat-square&logo=fastapi)](https://fastapi.tiangolo.com)
[![Python](https://img.shields.io/badge/Python-3.10+-3776AB?style=flat-square&logo=python)](https://python.org)
[![Dart](https://img.shields.io/badge/Dart-3.0+-0175C2?style=flat-square&logo=dart)](https://dart.dev)
[![License](https://img.shields.io/badge/License-MIT-green?style=flat-square)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20Desktop-blue?style=flat-square)](https://flutter.dev/desktop)

**A full-stack, real-time industrial motor control and predictive maintenance dashboard built with Flutter + FastAPI, targeting the INVT GD200A Variable Frequency Drive (VFD) and PZEM-004T power meter.**

[Overview](#-overview) • [Architecture](#-architecture) • [Features](#-features) • [Quick Start](#-quick-start) • [API Reference](#-api-reference) • [Screenshots](#-ui-walkthrough) • [Configuration](#-configuration)

</div>

---

## 📌 Overview

Motor Dashboard is a **production-grade, industry-level** desktop application for real-time VFD (Variable Frequency Drive) monitoring, motor control, power metering, alert management, and AI-driven predictive maintenance. It was built to address a real industrial requirement: controlling a three-phase induction motor connected to an **INVT GD200A VFD** via Modbus RTU, with power quality monitoring from a **PZEM-004T** energy meter.

### What problem does it solve?

| Problem | Solution |
|---|---|
| Motor faults go undetected until failure | Real-time alerts + OC trip with auto E-STOP |
| Manual serial data logging is error-prone | 500 ms background polling → SQLite history |
| Operators need remote visibility | WebSocket live stream at 2 Hz to any connected client |
| Power quality is hard to correlate with load | Dual VFD + PZEM data side-by-side |
| No structured fault prediction | AI-driven predictive maintenance module |

### Hardware It Targets

```
[PC running MotorDash]
        │
        ├─ USB→RS485 ──► INVT GD200A VFD ──► 3-Phase Motor
        │                 (Modbus RTU)
        │
        └─ USB→RS485 ──► PZEM-004T Power Meter
                          (Modbus RTU)
```

> **No hardware? No problem.** The backend auto-starts in **simulation mode** with realistic synthetic data — the full UI works without any physical devices.

---

## 🎬 Demo

> _Below are representative screenshots of each screen. Run `python run.py` then `flutter run -d windows` to see live._

### Splash & Login

```
┌────────────────────────────────────────────────────────┐
│                                                        │
│             ⚙  Motor Dashboard                         │
│          Predictive Maintenance System                 │
│                                                        │
│         ████████████████████  Initializing…           │
│                                                        │
└────────────────────────────────────────────────────────┘
```
- Animated fade-in with scale transition
- Auth check on boot (persisted via SharedPreferences)
- Three demo roles: **admin**, **operator**, **viewer**

---

### Main Dashboard

```
┌──────────┬──────────────────────────────────────────────────────────────────────┐
│MotorDash │  Dashboard                  ● VFD Online  ● Motor Running   ↻       │
│          ├──────────┬──────────┬──────────┬──────────┬──────────┬──────────┬──┤
│● Motor:  │ 1450 RPM │ 48.5 Hz  │ 4.20 A   │ 231.4 V  │ 226 V    │ 875 W    │..│
│  FWD     ├──────────┴──────────┴──────────┴──────────┴──────────┴──────────┴──┤
│          │                                                                      │
│⚡Connect  │  ┌─────────────────────┐  ┌─────────────────────┐  ┌────────────┐  │
│          │  │  Motor Control      │  │  RPM (Live) ━━━━━━  │  │Torque(Live)│  │
│📡Monitor  │  │  ● FWD              │  │  1450 ──────────    │  │   ~~~~     │  │
│          │  │  Direction: [FWD▼]  │  │                     │  │            │  │
│🔔Alerts   │  │  Freq: ──●── 48.5Hz│  └─────────────────────┘  └────────────┘  │
│          │  │  [▶ Start] [■ Stop] │                                            │
│📋Logs    │  │  [⚠ E-Stop][↺ Reset]│  ┌────────┐  ┌──────────────┐  ┌────────┐ │
│          │  └─────────────────────┘  │ Load   │  │Power vs Wt   │  │Alerts  │ │
│📊History │                           │Analysis│  │  ·  · ·  ·   │  │✓ Clear │ │
│          │                           └────────┘  └──────────────┘  └────────┘ │
│🤖AI Maint│                                                                      │
│          │                                                                      │
│⚙Settings │                                                                      │
│          │                                                                      │
│[A] admin │                                              ◆ ARIA (chatbot fab)   │
└──────────┴──────────────────────────────────────────────────────────────────────┘
```

**7 KPI tiles** (RPM, Hz, A, V, W, PF, V-out) auto-scale across screen sizes. Every tile is a `ValueListenableBuilder` — **only the tile with changed data repaints**.

---

### Live Monitor Screen

Displays all 15+ VFD registers and 6 PZEM registers individually in a responsive wrap grid.

```
┌────────────────────────────────────────────────────────────────────┐
│ Live Monitor                                    ● Live  [■ STOP]   │
├────────────────────────────────────────────────────────────────────┤
│  VFD Readings (GD200A)                                  ● Live     │
│                                                                     │
│  ┌───────────┐ ┌───────────┐ ┌───────────┐ ┌───────────┐          │
│  │ 48.5      │ │ 48.5      │ │ 226       │ │ 4.20      │          │
│  │ Set Freq  │ │ Out Freq  │ │ Out Volt  │ │ Out Curr  │          │
│  │     Hz    │ │     Hz    │ │      V    │ │      A    │          │
│  └───────────┘ └───────────┘ └───────────┘ └───────────┘          │
│  ┌───────────┐ ┌───────────┐ ┌───────────┐ ┌───────────┐          │
│  │ 1450      │ │ 875       │ │ 0.95      │ │ 231       │          │
│  │ Motor RPM │ │ Act Power │ │ Pwr Factor│ │ Inp Volt  │          │
│  └───────────┘ └───────────┘ └───────────┘ └───────────┘          │
│  ... Phase R / Y / B tiles ...                                      │
│                                                                     │
│  Power Meter (PZEM-004T)                                ● Live     │
│  ┌───────────┐ ┌───────────┐ ┌───────────┐ ...                    │
│  │ 231.4     │ │ 3.85      │ │ 840       │                         │
│  │ Voltage   │ │ Current   │ │ Power     │                         │
│  └───────────┘ └───────────┘ └───────────┘                         │
└────────────────────────────────────────────────────────────────────┘
```

---

### Alerts Screen

```
┌────────────────────────────────────────────────────┐
│ Alerts  [2 active]                            ↻    │
├────────────────────────────────────────────────────┤
│ ┌──────────────────────────────────────────────┐   │
│ │ 🔴 CRITICAL  OC_TRIP        14:32:01 12 Jun  │   │
│ │    Current exceeded threshold for >1s        │   │
│ │    current: 11.2A  |  threshold: 10.0A  [Ack]│   │
│ └──────────────────────────────────────────────┘   │
│ ┌──────────────────────────────────────────────┐   │
│ │ 🟡 WARNING  UNDERVOLTAGE    14:31:55 12 Jun  │   │
│ │    Voltage dropped below 195V                │   │
│ │    voltage: 192.3V                      [Ack]│   │
│ └──────────────────────────────────────────────┘   │
└────────────────────────────────────────────────────┘
```

---

### AI Predictive Maintenance

```
┌────────────────────────────────────────────────────────────────────┐
│ Predictive Maintenance                           [Run Analysis →]   │
│ AI-driven machine health and failure risk analysis                  │
├──────────────────────────────────────────────────────────────────── │
│ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐               │
│ │ 4 UNITS  │ │ 1 CRIT   │ │ 3 STABLE │ │ 75% HLTH │               │
│ │ Total    │ │ At Risk  │ │ Healthy  │ │ Score    │               │
│ └──────────┘ └──────────┘ └──────────┘ └──────────┘               │
│                                                                      │
│ ┌─────────────────────────────┐  ┌──────────────────┐              │
│ │ Monitored Assets            │  │ Risk Distribution│              │
│ │  ⚙ M-001 VFD Motor A  ●OK  │  │   🟢 75% Normal  │              │
│ │  ⚙ M-002 VFD Motor B  ⚠Wrn │  │   🟡 25% Warning │              │
│ │  ⚙ M-003 Pump Motor   ●OK  │  │                  │              │
│ │  ⚙ M-004 Conveyor     ●OK  │  │  [Pie Chart]     │              │
│ └─────────────────────────────┘  └──────────────────┘              │
└────────────────────────────────────────────────────────────────────┘
```

---

## 🏗 Architecture

The project is split into two independently runnable parts:

```
motor-backend/          ← FastAPI Python server
motor-frontend/         ← Flutter Windows desktop app
```

### Backend Architecture

```
motor-backend/
├── run.py                        ← Uvicorn entry point
├── requirements.txt
├── .env.example
├── drivers/
│   ├── gd200a.py                 ← INVT GD200A Modbus RTU driver (pyserial)
│   └── pzem004t.py               ← PZEM-004T power meter driver
└── app/
    ├── main.py                   ← FastAPI app + CORS + lifespan events
    ├── models/
    │   └── schemas.py            ← Pydantic v2 request/response models
    ├── services/
    │   ├── device_manager.py     ← Singleton — owns all hardware connections
    │   ├── poller.py             ← 500 ms asyncio background polling task
    │   └── alert_engine.py       ← Threshold-based stateful alert generator
    ├── db/
    │   └── database.py           ← Async SQLite via aiosqlite
    ├── routers/
    │   ├── motor.py              ← Motor control endpoints
    │   ├── monitor.py            ← Live + historical data
    │   ├── ports.py              ← Serial port discovery
    │   ├── logs.py               ← Event log
    │   ├── alerts.py             ← Alerts CRUD + ack
    │   ├── reports.py            ← CSV export
    │   └── ws_router.py          ← WebSocket endpoints
    └── ws/
        └── connection_manager.py ← Multi-client WS broadcaster
```

**Key design decisions:**
- `DeviceManager` is a **singleton** — only one object ever holds the serial port handles
- Poller runs as an **asyncio task** (not a thread), writing to an in-memory state dict
- WebSocket broadcaster fans out from a single poller read — no per-client polling
- SQLite is async via `aiosqlite` — no blocking I/O on the event loop

### Frontend Architecture

```
motor-frontend/lib/
├── main.dart                             ← Provider tree + MaterialApp
├── core/
│   ├── models/
│   │   └── motor_models.dart             ← VfdData, PzemData, MonitorData, AlertModel
│   ├── providers/
│   │   ├── motor_provider.dart           ← Primary ChangeNotifier (motor commands, status)
│   │   ├── auth_provider.dart            ← Auth state (login/logout/role)
│   │   ├── theme_provider.dart           ← Light/Dark/System toggle
│   │   └── maintenance_provider.dart     ← AI maintenance REST calls
│   ├── services/
│   │   ├── api_service.dart              ← HTTP REST client (timeout-wrapped)
│   │   ├── auth_service.dart             ← SharedPreferences credential store
│   │   ├── motor_data_worker.dart        ← Isolate-based WS JSON decoder + chart aggregator
│   │   └── motor_ws_isolate.dart         ← Alternative isolate bridge (reconnect backoff)
│   └── theme/
│       └── app_theme.dart                ← AppColors + AppTheme (dark + light)
├── ui/
│   ├── router/
│   │   └── app_router.dart               ← Named route generator
│   ├── screens/
│   │   ├── splash_screen.dart
│   │   ├── login_screen.dart
│   │   ├── dashboard_screen.dart
│   │   ├── monitor_screen.dart
│   │   ├── alerts_screen.dart
│   │   ├── logs_screen.dart
│   │   ├── history_screen.dart
│   │   ├── connect_screen.dart
│   │   ├── settings_screen.dart
│   │   └── maintenance/
│   │       ├── dashboard_screen.dart
│   │       ├── run_analysis_screen.dart
│   │       └── machine_detail_screen.dart
│   └── widgets/
│       ├── app_shell.dart                ← Sidebar + content layout shell
│       ├── glass_card.dart               ← GlassCard, MetricTile, StatusChip
│       ├── motor_data_notifiers.dart     ← Fine-grained ValueNotifiers (VFD, PZEM, Charts)
│       ├── aria_chatbot.dart             ← Floating AI assistant widget
│       └── premium_button.dart           ← Gradient button widget
```

### Data Flow — From Hardware to Pixel

```
[GD200A VFD] ──Modbus RTU──► [gd200a.py driver]
                                      │
                              [device_manager.py]
                                      │
                              [poller.py — 500ms asyncio]
                                      │
                              [SQLite write + WS broadcast]
                                      │
                    ┌─────────────────┴────────────────┐
                    ▼                                   ▼
          [/ws/monitor stream]               [/api/history REST]
                    │
          [motor_data_worker.dart]     ← Background Dart isolate
          [JSON decode + chart queues]   (never blocks UI thread)
                    │
          [MotorDataNotifiers]         ← Fine-grained ValueNotifiers
          [vfd / pzem / charts]          per data domain
                    │
          [ValueListenableBuilder]     ← Only affected widget repaints
          [in each UI widget]
```

**Why isolates?** Flutter runs on a single UI thread. JSON decoding 500 ms WebSocket frames at scale causes jank. The `MotorDataWorkerBridge` spawns a Dart `Isolate` that handles all JSON parsing, chart queue management, and throttling. The UI thread only receives pre-built `Map<String, dynamic>` snapshots.

---

## ✨ Features

### Motor Control
| Feature | Details |
|---|---|
| Start / Stop | Set direction (FWD/REV) and frequency (0.5–50 Hz) before start |
| Emergency Stop | Coast-to-stop via VFD register write |
| Fault Reset | Clears CE fault without power cycle |
| Real-time Frequency Adjust | Slider with `onChangeEnd` — sends Hz only when user releases |
| Overcurrent Trip | Auto E-STOP when current > threshold for > 1 second |
| Role-based Controls | Viewer role sees controls but cannot operate them |

### Monitoring
| Feature | Details |
|---|---|
| VFD Registers | Set freq, output freq/volt/current, RPM, power, PF, input volt, proximity RPM, Phase R/Y/B |
| PZEM Readings | Voltage, current, power, energy (Wh), frequency, power factor |
| Live Charts | Rolling 60-sample RPM and Torque trend charts (500ms cadence) |
| Historical Data | SQLite-backed, query by time range, CSV export |
| WebSocket clients | Backend tracks connected WS client count per channel |

### Alerts Engine
| Alert Type | Severity | Trigger Condition |
|---|---|---|
| `OC_WARNING` | WARNING | Current > 85% of OC threshold |
| `OC_TRIP` | CRITICAL | Current > threshold for > 1 second → auto E-STOP |
| `OVERVOLTAGE` | CRITICAL | Voltage > 265 V |
| `UNDERVOLTAGE` | WARNING | Voltage < 195 V |
| `OVERFREQ` | WARNING | Output frequency > 51 Hz |
| `LOW_PF` | INFO | Power factor < 0.70 |
| `VFD_COMMS` | CRITICAL | VFD read failed while motor state is running |

Alerts are:
- Persisted in SQLite
- Pushed in real-time via `/ws/alerts` WebSocket
- Acknowledgeable per-alert by operator/admin roles

### Load Analysis (Power vs Weight)
The dashboard includes a **spring balance load analysis tool** for correlating motor power and torque against mechanical load weight. Operators input S1 (loaded) and S2 (tare) readings; the app plots scatter charts of Power vs Weight and Torque vs Weight for efficiency characterisation.

### AI Predictive Maintenance
The `/maintenance` section connects to a predictive backend (default `http://localhost:8000/predictive`) that accepts sensor readings (temperature, vibration, pressure, RPM) and returns:
- **Risk level** (Low / Medium / High / Critical)
- **Failure probability** (0.0–1.0)
- **Anomaly list**
- **Maintenance recommendation**
- Per-agent status cards (Monitoring Agent, Prediction Agent, Maintenance Agent)

The **Run Analysis** screen auto-populates RPM from live VFD data when the motor is running.

### ARIA Chatbot
A floating hexagonal FAB in the bottom-right corner opens the **ARIA AI Assistant** — a chat panel that sends messages to `POST /api/chat` with the current motor context (state, VFD readings, PZEM readings) for contextual motor-system Q&A.

### Auth & Roles
| Role | Permissions |
|---|---|
| `admin` | Full access: controls, settings, alerts, reports |
| `operator` | Motor start/stop/E-stop, alert acknowledge |
| `viewer` | Read-only: all data visible, controls disabled |

Credentials are stored locally via SharedPreferences (demo mode). Replace `AuthService._demoAccounts` with a real JWT/OAuth call for production.

---

## 🚀 Quick Start

### Prerequisites

| Tool | Version |
|---|---|
| Python | 3.10+ |
| Flutter | 3.38+ (stable channel) |
| Dart | 3.0+ |
| Windows | 10/11 (desktop target) |

### 1 — Backend Setup

```bash
# Clone the repository
git clone https://github.com/your-org/motor-dashboard.git
cd motor-dashboard/motor-backend

# Create a virtual environment
python -m venv venv
venv\Scripts\activate          # Windows
# source venv/bin/activate     # Linux/Mac

# Install dependencies
pip install -r requirements.txt

# Copy environment config
cp .env.example .env

# Start the server
python run.py
```

Server starts at **http://localhost:8000**
Interactive API docs: **http://localhost:8000/docs**

> **Simulation mode** activates automatically if no VFD/PZEM ports are provided at `/api/connect`. You will see realistic sine-wave motor data immediately.

### 2 — Frontend Setup

```bash
cd motor-dashboard/motor-frontend

# Get Flutter dependencies
flutter pub get

# Run on Windows desktop
flutter run -d windows

# Or build a release executable
flutter build windows --release
```

### 3 — Connect to Hardware (Optional)

1. Wire your RS-485 adapters to GD200A (P14 registers below) and PZEM-004T
2. Open the app → **VFD Connect** screen
3. Enter your COM port numbers and click **Connect Devices**
4. Or enable **Simulation Mode** toggle to run without hardware

#### Required VFD Parameter Settings (GD200A)

Before the VFD will accept Modbus commands, configure these parameters via the keypad:

| Parameter | Value | Description |
|---|---|---|
| `P00.01` | `2` | Command source = Modbus RTU |
| `P00.06` | `8` | Frequency source A = Modbus |
| `P14.00` | `1` | Slave address = 1 |
| `P14.01` | `3` | Baud rate = 9600 |
| `P14.02` | `0` | Format = N,8,1 RTU |
| `P14.04` | `0.0` | Comm overtime = DISABLED (fixes CE fault on reconnect) |
| `P14.05` | `1` | Timeout action = no alarm |

---

## 📡 API Reference

### Connection Endpoints

| Method | Endpoint | Body | Description |
|---|---|---|---|
| `POST` | `/api/connect` | `{vfd_port, pzem_port, vfd_baud, simulate}` | Connect to VFD and/or PZEM |
| `POST` | `/api/disconnect` | — | Disconnect all devices, stop poller |
| `GET` | `/api/status` | — | Returns connection state + motor state + thresholds |
| `GET` | `/api/ports` | — | Lists available serial COM ports |

### Motor Control Endpoints

| Method | Endpoint | Body | Description |
|---|---|---|---|
| `POST` | `/api/motor/start` | `{direction, frequency, target_rpm}` | Start motor |
| `POST` | `/api/motor/stop` | — | Decelerate stop |
| `POST` | `/api/motor/estop` | — | Emergency coast stop |
| `POST` | `/api/motor/reset` | — | Clear CE fault |
| `POST` | `/api/motor/frequency` | `{frequency}` | Set output frequency while running |
| `POST` | `/api/motor/oc-threshold` | `{threshold_amps}` | Update overcurrent trip level |

### Data Endpoints

| Method | Endpoint | Query Params | Description |
|---|---|---|---|
| `GET` | `/api/monitor` | — | Single-shot live reading snapshot |
| `GET` | `/api/history` | `limit, start_ts, end_ts` | Historical readings from SQLite |
| `GET` | `/api/logs` | `limit` | Event log entries |
| `GET` | `/api/alerts` | — | Active + recent alerts |
| `POST` | `/api/alerts/{id}/ack` | — | Acknowledge an alert by ID |
| `GET` | `/api/reports/export` | — | Download CSV of all history |
| `POST` | `/api/chat` | `{message, context}` | ARIA chatbot endpoint |

### WebSocket Endpoints

| WS | Endpoint | Payload | Cadence |
|---|---|---|---|
| `WS` | `/ws/monitor` | `{timestamp, motor_state, vfd:{...}, pzem:{...}}` | 500 ms |
| `WS` | `/ws/alerts` | `{id, type, message, severity, timestamp, data}` | On event |

#### WebSocket Monitor Payload Schema

```json
{
  "timestamp": 1718000000.0,
  "motor_state": "FWD",
  "vfd": {
    "set_freq": 48.5,
    "out_freq": 48.4,
    "out_volt": 226.0,
    "out_curr": 4.20,
    "motor_rpm": 1450,
    "power": 875.0,
    "pf": 0.95,
    "inp_volt": 231.0,
    "prox_rpm": 1448.0,
    "phase_r": 231.0,
    "phase_y": 230.5,
    "phase_b": 231.2,
    "source": "hardware"
  },
  "pzem": {
    "voltage": 231.4,
    "current": 3.85,
    "power": 840.0,
    "energy": 12340.0,
    "freq": 49.97,
    "pf": 0.94
  }
}
```

#### JavaScript WebSocket Usage

```javascript
// Live monitor stream
const ws = new WebSocket("ws://localhost:8000/ws/monitor");
ws.onmessage = (event) => {
  const { vfd, pzem, motor_state } = JSON.parse(event.data);
  console.log(`RPM: ${vfd.motor_rpm}  |  Current: ${pzem.current}A`);
};

// Alert push stream
const alertWs = new WebSocket("ws://localhost:8000/ws/alerts");
alertWs.onmessage = (event) => {
  const alert = JSON.parse(event.data);
  if (alert.severity === "CRITICAL") showEmergencyModal(alert);
};
```

---

## 🖥 UI Walkthrough

### Navigation

The app uses a **collapsible sidebar** (240 px expanded / 68 px icon-only) with these sections:

| Icon | Route | Description |
|---|---|---|
| 📊 | `/` Dashboard | KPI grid, motor control, live charts, load analysis |
| 🔌 | `/connect` | Serial port configuration, device connect/disconnect |
| 📡 | `/monitor` | All individual VFD + PZEM register tiles |
| 🔔 | `/alerts` | Active alerts with severity, acknowledge button |
| 📋 | `/logs` | Event log with level filter chips |
| 📈 | `/history` | Historical trend chart + data table with CSV export |
| 🤖 | `/maintenance` | AI maintenance dashboard + risk pie chart |
| 🔬 | `/maintenance/analyze` | Run AI analysis with sensor input form |
| ⚙ | `/settings` | Theme, server URL, OC threshold, user info, sign out |

### Responsive Layout

The dashboard uses `LayoutBuilder` with three breakpoints:

| Width | Layout |
|---|---|
| > 1200 px | 7-column KPI grid, side-by-side motor control + 2 charts |
| 800–1200 px | 4-column grid, stacked rows |
| < 800 px | 2-column grid, vertical stack |

### Theming

Full **light and dark theme** support via `ThemeProvider`. Themes are defined in `app_theme.dart` using Material 3 `ColorScheme`. All colors reference `AppColors` constants — no hard-coded hex in widgets.

```
Dark palette:  bg900 (#0A0F1E) → bg800 (#0F172A) → surface (#1E293B)
Light palette: lightBg (#F8FAFC) → lightSurface (#FFFFFF)
Primary:       #0EA5E9 (sky-500)
Accent:        #06B6D4 (cyan-500)
```

---

## ⚙ Configuration

### Backend `.env` File

```env
# Serial port defaults (overridden at runtime via /api/connect)
VFD_PORT=COM4
PZEM_PORT=COM3
VFD_BAUD=9600
PZEM_BAUD=9600

# Polling interval in milliseconds
POLL_INTERVAL_MS=500

# SQLite database path
DB_PATH=./motor_data.db

# Alert thresholds (can be overridden at runtime)
OC_THRESHOLD_AMPS=10.0
MAX_VOLTAGE=265.0
MIN_VOLTAGE=195.0
MAX_FREQ_HZ=51.0
MIN_PF=0.70

# CORS (add your frontend origin if deploying separately)
ALLOWED_ORIGINS=*
```

### Flutter Server URL

The default backend URL is `http://localhost:8000`. Change it at runtime in **Settings** screen → **API Server URL**, or update the default in `api_service.dart`:

```dart
String _baseUrl = 'http://192.168.1.100:8000'; // your server IP
```

---

## 🧪 Testing & Development

### Simulation Mode

Start the backend, open the app, go to **VFD Connect**, toggle **Simulation Mode ON**, and click **Connect Devices**. No port fields are required. The backend generates:
- Sinusoidal RPM oscillation around a setpoint
- Realistic current/voltage with noise
- Randomised power factor variation
- Triggered alerts at configurable thresholds

### Backend API Docs

With the server running, visit:
- **Swagger UI:** `http://localhost:8000/docs`
- **ReDoc:** `http://localhost:8000/redoc`

### Running Flutter Tests

```bash
cd motor-frontend
flutter test
```

The `widget_test.dart` smoke test verifies the app builds and renders without crashing.

---

## 📦 Dependencies

### Backend (`requirements.txt`)

| Package | Purpose |
|---|---|
| `fastapi` | REST API framework |
| `uvicorn` | ASGI server |
| `pyserial` | Serial port communication |
| `aiosqlite` | Async SQLite |
| `pydantic` | Request/response validation |
| `python-dotenv` | `.env` config loading |

### Frontend (`pubspec.yaml`)

| Package | Purpose |
|---|---|
| `provider` | State management |
| `http` | REST API calls |
| `web_socket_channel` | WebSocket client |
| `fl_chart` | Line, scatter, pie charts |
| `google_fonts` | Inter typeface |
| `shared_preferences` | Auth token persistence |
| `intl` | Date/time formatting |
| `flutter_svg` | SVG asset rendering |
| `lottie` | Animation support |
| `url_launcher` | CSV report download |

---

## 🔒 Security Notes

- The current `AuthService` uses hardcoded demo credentials. For production, replace `_demoAccounts` with a real API call that returns a JWT.
- The backend CORS is set to `*` by default. Restrict `ALLOWED_ORIGINS` to your frontend origin in production.
- Serial port access requires the running process to have appropriate OS permissions (no sudo needed on Windows with standard USB-serial drivers).

---

## 🗺 Roadmap

- [ ] JWT authentication with server-side session management
- [ ] Multi-motor support (multiple VFD instances)
- [ ] OPC-UA protocol support as alternative to Modbus
- [ ] Email/SMS alert notifications
- [ ] Real ML model integration for predictive maintenance (LSTM / Isolation Forest)
- [ ] Android/iOS mobile companion app (Flutter multiplatform)
- [ ] Grafana-compatible metrics export

---

## 📁 Project Structure Summary

```
motor-dashboard/
│
├── motor-backend/              ← Python FastAPI backend
│   ├── run.py
│   ├── requirements.txt
│   ├── .env.example
│   ├── drivers/
│   │   ├── gd200a.py           ← INVT GD200A Modbus RTU driver
│   │   └── pzem004t.py         ← PZEM-004T power meter driver
│   └── app/
│       ├── main.py
│       ├── models/schemas.py
│       ├── services/           ← device_manager, poller, alert_engine
│       ├── db/database.py
│       ├── routers/            ← motor, monitor, ports, logs, alerts, reports, ws
│       └── ws/connection_manager.py
│
└── motor-frontend/             ← Flutter Windows desktop app
    ├── pubspec.yaml
    ├── lib/
    │   ├── main.dart
    │   ├── core/
    │   │   ├── models/
    │   │   ├── providers/      ← motor, auth, theme, maintenance
    │   │   ├── services/       ← api, auth, worker isolate, websocket
    │   │   └── theme/
    │   └── ui/
    │       ├── router/
    │       ├── screens/        ← 9 screens + 3 maintenance sub-screens
    │       └── widgets/        ← shell, cards, notifiers, chatbot
    └── windows/                ← Win32 runner boilerplate
```

---

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/my-feature`
3. Commit your changes: `git commit -m 'feat: add my feature'`
4. Push to the branch: `git push origin feature/my-feature`
5. Open a Pull Request

Please follow the existing code style — Dart with `flutter_lints`, Python with type hints.

---

## 📄 License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.

---

<div align="center">

Built with ❤️ using Flutter + FastAPI

**INVT GD200A VFD + PZEM-004T · Real-time WebSocket · Predictive Maintenance · ARIA AI Assistant**

</div>
