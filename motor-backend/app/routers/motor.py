"""
Motor Control Router
====================
POST /api/connect
POST /api/disconnect
GET  /api/status
POST /api/motor/start
POST /api/motor/stop
POST /api/motor/estop
POST /api/motor/reset
POST /api/motor/frequency
POST /api/motor/oc-threshold
"""

from fastapi import APIRouter
from app.models.schemas import (
    ConnectRequest, StartMotorRequest, SetFrequencyRequest,
    SetOCThresholdRequest, CommandResponse, StatusResponse
)
from app.services.device_manager import DeviceManager
from app.db.database import log_event
from app.ws.connection_manager import ws_monitor_manager, ws_alert_manager
import time

router = APIRouter()


# ── Connect / Disconnect ───────────────────────────────────────────────────────

@router.post("/connect", response_model=CommandResponse)
async def connect_devices(req: ConnectRequest):
    dm = DeviceManager.get_instance()
    results = {}

    if req.vfd_port:
        r = await dm.connect_vfd(req.vfd_port, req.vfd_baud)
        results["vfd"] = r
        if r["success"]:
            await log_event("CONNECT", f"VFD connected on {req.vfd_port}")
        else:
            await log_event("ERROR", f"VFD connection failed on {req.vfd_port}: {r.get('error')}")

    if req.pzem_port:
        r = await dm.connect_pzem(req.pzem_port, req.pzem_baud)
        results["pzem"] = r
        if r["success"]:
            await log_event("CONNECT", f"PZEM connected on {req.pzem_port}")
        else:
            await log_event("ERROR", f"PZEM connection failed on {req.pzem_port}: {r.get('error')}")

    any_ok  = any(v.get("success") for v in results.values())
    any_err = [v.get("error") for v in results.values() if not v.get("success")]

    return CommandResponse(
        success=any_ok,
        message="Device(s) connected" if any_ok else "Connection failed",
        error="; ".join(filter(None, any_err)) or None,
        data=results,
    )


@router.post("/disconnect", response_model=CommandResponse)
async def disconnect_devices():
    dm = DeviceManager.get_instance()
    await dm.disconnect_all()
    await log_event("DISCONNECT", "All devices disconnected")
    return CommandResponse(success=True, message="All devices disconnected")


@router.get("/status", response_model=StatusResponse)
async def get_status():
    dm = DeviceManager.get_instance()
    return StatusResponse(
        vfd_connected=dm.vfd_connected,
        pzem_connected=dm.pzem_connected,
        motor_state=dm.motor_state,
        oc_threshold=dm.oc_threshold,
        simulation_mode=dm.simulation_mode,
        ws_monitor_clients=ws_monitor_manager.client_count,
        ws_alert_clients=ws_alert_manager.client_count,
        timestamp=time.time(),
    )


# ── Motor Commands ─────────────────────────────────────────────────────────────

@router.post("/motor/start", response_model=CommandResponse)
async def start_motor(req: StartMotorRequest):
    dm = DeviceManager.get_instance()

    # Determine target frequency
    hz = req.frequency
    if req.target_rpm is not None:
        hz = dm.rpm_to_hz(req.target_rpm)
    elif hz is None:
        hz = 25.0  # default fallback

    # Clamp frequency for safety
    hz = max(0.5, min(50.0, hz))

    # Direction + Frequency (atomic)
    if req.direction == "forward":
        res = await dm.run_forward(hz=hz)
    else:
        res = await dm.run_reverse(hz=hz)

    if res["success"]:
        dm._freq = hz  # update sim state just in case
        await log_event("MOTOR", f"Motor START {req.direction.upper()} @ {hz:.2f} Hz")
    else:
        await log_event("ERROR", f"Motor start failed: {res.get('error', '')}")

    return CommandResponse(
        success=res["success"],
        message=f"Motor started {req.direction} at {hz:.2f} Hz" if res["success"] else "Start failed",
        error=res.get("error"),
        data={"direction": req.direction, "frequency": hz, "target_rpm": req.target_rpm},
    )


@router.post("/motor/stop", response_model=CommandResponse)
async def stop_motor():
    dm = DeviceManager.get_instance()
    res = await dm.stop_motor()
    await log_event("MOTOR", "Motor STOP (decelerate)")
    return CommandResponse(
        success=res["success"],
        message="Motor stopping (decelerate)" if res["success"] else "Stop command failed",
        error=res.get("error"),
    )


@router.post("/motor/estop", response_model=CommandResponse)
async def estop_motor():
    dm = DeviceManager.get_instance()
    res = await dm.estop_motor()
    await log_event("MOTOR", "Motor E-STOP (coast)")
    return CommandResponse(
        success=res["success"],
        message="Emergency stop activated (coast)" if res["success"] else "E-STOP failed",
        error=res.get("error"),
    )


@router.post("/motor/reset", response_model=CommandResponse)
async def reset_fault():
    dm = DeviceManager.get_instance()
    res = await dm.reset_fault()
    await log_event("MOTOR", "Fault RESET sent")
    return CommandResponse(
        success=res["success"],
        message="Fault reset sent — CE should be cleared" if res["success"] else "Fault reset failed",
        error=res.get("error"),
    )


@router.post("/motor/frequency", response_model=CommandResponse)
async def set_frequency(req: SetFrequencyRequest):
    dm = DeviceManager.get_instance()
    
    # Determine target frequency
    hz = req.frequency
    if req.target_rpm is not None:
        hz = dm.rpm_to_hz(req.target_rpm)
    elif hz is None:
        hz = 25.0
        
    # Clamp safety bounds
    hz = max(0.5, min(50.0, hz))
    
    res = await dm.set_frequency(hz)
    if res["success"]:
        await log_event("MOTOR", f"Frequency/RPM dynamically set to {hz:.2f} Hz")
        return CommandResponse(
            success=True,
            message=f"Speed updated to {hz:.2f} Hz",
            data={"frequency_hz": hz, "target_rpm": req.target_rpm},
        )
    else:
        await log_event("ERROR", f"Failed to modify speed: {res.get('error')}")
        return CommandResponse(
            success=False,
            message="Speed update failed",
            error=res.get("error")
        )


@router.post("/motor/oc-threshold", response_model=CommandResponse)
async def set_oc_threshold(req: SetOCThresholdRequest):
    dm = DeviceManager.get_instance()
    dm.set_oc_threshold(req.threshold_amps)
    await log_event("CONFIG", f"OC threshold set to {req.threshold_amps:.2f} A")
    return CommandResponse(
        success=True,
        message=f"OC threshold updated to {req.threshold_amps:.2f} A",
        data={"threshold_amps": req.threshold_amps},
    )
