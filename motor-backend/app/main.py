"""
╔══════════════════════════════════════════════════════════════════════════════╗
║  Predictive Maintenance — FastAPI Backend                                   ║
║  INVT GD200A VFD + PZEM-004T  ·  Industry-Level REST + WebSocket API       ║
║  Theem College of Engineering, Boisar                                       ║
╚══════════════════════════════════════════════════════════════════════════════╝

Endpoints:
  POST /api/connect              — connect to VFD and/or PZEM
  POST /api/disconnect           — disconnect all devices
  GET  /api/status               — connection + motor state
  POST /api/motor/start          — start motor (fwd/rev + freq)
  POST /api/motor/stop           — decelerate stop
#   POST /api/motor/estop          — emergency coast stop 
  POST /api/motor/reset          — clear CE fault
  POST /api/motor/frequency      — set frequency only
  GET  /api/monitor              — single-shot live readings
  GET  /api/ports                — list available serial ports
  GET  /api/logs                 — recent event log (last N entries)
  GET  /api/history              — historical data from DB
  GET  /api/alerts               — active + recent alerts
  POST /api/alerts/{id}/ack      — acknowledge an alert
  GET  /api/reports/export       — download CSV report
  WS   /ws/monitor               — WebSocket live data stream (500 ms)
  WS   /ws/alerts                — WebSocket alert stream
  POST /api/chat                 — ARIA AI chatbot (personality-driven)
"""

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager
import logging

from app.routers import motor, monitor, ports, logs, alerts, reports, ws_router, maintenance, chat
from app.db.database import init_db
from app.services.poller import PollerService

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s — %(message)s",
)
logger = logging.getLogger("motor.main")


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Startup / shutdown lifecycle."""
    logger.info("Starting Motor API server…")
    await init_db()
    poller = PollerService.get_instance()
    await poller.start()
    yield
    logger.info("Shutting down Motor API server…")
    await poller.stop()


app = FastAPI(
    title="Predictive Maintenance API",
    description="Industry-level REST + WebSocket API for INVT GD200A VFD motor control and monitoring.",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
    lifespan=lifespan,
)

# ── CORS ─────────────────────────────────────────────────────────────────────
# Allow the Electron/React frontend (localhost:3000) and any cloud domain.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],          # tighten to specific origins in production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── Routers ───────────────────────────────────────────────────────────────────
app.include_router(motor.router,   prefix="/api", tags=["Motor Control"])
app.include_router(monitor.router, prefix="/api", tags=["Monitoring"])
app.include_router(ports.router,   prefix="/api", tags=["Serial Ports"])
app.include_router(logs.router,    prefix="/api", tags=["Event Log"])
app.include_router(alerts.router,  prefix="/api", tags=["Alerts"])
app.include_router(reports.router, prefix="/api", tags=["Reports"])
app.include_router(maintenance.router, prefix="/api", tags=["Predictive Maintenance"])
app.include_router(chat.router, prefix="/api", tags=["ARIA AI Assistant"])
app.include_router(ws_router.router, tags=["WebSocket"])


@app.get("/", tags=["Health"])
async def root():
    return {"status": "ok", "service": "Predictive Maintenance API v1.0.0"}


@app.get("/health", tags=["Health"])
async def health():
    from app.services.device_manager import DeviceManager
    dm = DeviceManager.get_instance()
    return {
        "status": "ok",
        "vfd_connected": dm.vfd_connected,
        "pzem_connected": dm.pzem_connected,
    }
