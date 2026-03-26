# Predictive Maintenance API — FastAPI Backend
## INVT GD200A VFD + PZEM-004T · Industry-Level REST + WebSocket

---

## 📐 Architecture

```
motor-backend/
├── run.py                          ← Start server here
├── requirements.txt
├── .env.example
├── drivers/
│   ├── gd200a.py                   ← GD200A Modbus RTU driver (pure pyserial)
│   └── pzem004t.py                 ← PZEM-004T power meter driver
└── app/
    ├── main.py                     ← FastAPI app + CORS + lifespan
    ├── models/
    │   └── schemas.py              ← Pydantic request/response models
    ├── services/
    │   ├── device_manager.py       ← Singleton — owns hardware connections
    │   ├── poller.py               ← 500 ms background polling task
    │   └── alert_engine.py         ← Threshold-based alert generator
    ├── db/
    │   └── database.py             ← Async SQLite (aiosqlite)
    ├── routers/
    │   ├── motor.py                ← Motor control endpoints
    │   ├── monitor.py              ← Live + historical data
    │   ├── ports.py                ← Serial port discovery
    │   ├── logs.py                 ← Event log
    │   ├── alerts.py               ← Alerts CRUD
    │   ├── reports.py              ← CSV export
    │   └── ws_router.py            ← WebSocket endpoints
    └── ws/
        └── connection_manager.py   ← Multi-client WS broadcaster
```

---

## 🚀 Quick Start

```bash
# 1. Install dependencies
pip install -r requirements.txt

# 2. Copy environment config
cp .env.example .env

# 3. Start the server
python run.py
```

Server starts at **http://localhost:8000**
Interactive API docs: **http://localhost:8000/docs**

---

## 🔌 API Endpoints

### Connection
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/connect` | Connect VFD and/or PZEM |
| POST | `/api/disconnect` | Disconnect all devices |
| GET | `/api/status` | Connection + motor state |
| GET | `/api/ports` | List available COM ports |

### Motor Control
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/motor/start` | Start motor (direction + frequency) |
| POST | `/api/motor/stop` | Decelerate stop |
| POST | `/api/motor/estop` | Emergency coast stop |
| POST | `/api/motor/reset` | Clear CE fault |
| POST | `/api/motor/frequency` | Set frequency only |
| POST | `/api/motor/oc-threshold` | Set overcurrent trip level |

### Data
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/monitor` | Single-shot live reading |
| GET | `/api/history` | Historical readings (SQLite) |
| GET | `/api/logs` | Event log |
| GET | `/api/alerts` | Active + recent alerts |
| POST | `/api/alerts/{id}/ack` | Acknowledge an alert |
| GET | `/api/reports/export` | Download CSV report |

### WebSocket
| WS | Endpoint | Description |
|----|----------|-------------|
| WS | `/ws/monitor` | Live data stream (500 ms) |
| WS | `/ws/alerts` | Real-time alert push |

---

## 📡 WebSocket Usage (JavaScript)

```javascript
// Live monitor stream
const ws = new WebSocket("ws://localhost:8000/ws/monitor");
ws.onmessage = (event) => {
  const data = JSON.parse(event.data);
  console.log(data.vfd.motor_rpm, data.pzem.current);
};

// Alert stream
const alertWs = new WebSocket("ws://localhost:8000/ws/alerts");
alertWs.onmessage = (event) => {
  const alert = JSON.parse(event.data);
  if (alert.severity === "CRITICAL") showModal(alert.message);
};
```

---

## 🔴 Alert Types

| Type | Severity | Trigger |
|------|----------|---------|
| `OC_WARNING` | WARNING | Current > 85% of threshold |
| `OC_TRIP` | CRITICAL | Current > threshold for >1 s → auto E-STOP |
| `OVERVOLTAGE` | CRITICAL | Voltage > 265 V |
| `UNDERVOLTAGE` | WARNING | Voltage < 195 V |
| `OVERFREQ` | WARNING | Output freq > 51 Hz |
| `LOW_PF` | INFO | Power factor < 0.70 |
| `VFD_COMMS` | CRITICAL | VFD read failed while motor running |

---

## 🧪 Simulation Mode

If hardware is not connected, the server auto-detects and runs in **simulation mode** — generates realistic fake data for UI development. No hardware required.

Force simulation by simply not providing port values in `/api/connect`.

---

## ⚙️ VFD Settings Required

Before use, configure the GD200A:
```
P00.01 = 2   (command source = Modbus)
P00.06 = 8   (freq source A  = Modbus)
P14.00 = 1   (slave address)
P14.01 = 3   (baud = 9600)
P14.02 = 0   (N,8,1 RTU)
P14.04 = 0.0 (comm overtime DISABLED — fixes CE fault)
P14.05 = 1   (timeout action = no alarm)
```
