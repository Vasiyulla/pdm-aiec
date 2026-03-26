"""
Pydantic Models — request bodies and response schemas
"""

from pydantic import BaseModel, Field
from typing import Optional, Literal
import time


# ── Request Models ────────────────────────────────────────────────────────────

class ConnectRequest(BaseModel):
    vfd_port:   Optional[str] = Field(None,  example="COM7",        description="Serial port for GD200A VFD")
    pzem_port:  Optional[str] = Field(None,  example="COM5",        description="Serial port for PZEM-004T")
    vfd_baud:   int           = Field(9600,  example=9600,          description="VFD baud rate")
    pzem_baud:  int           = Field(9600,  example=9600,          description="PZEM baud rate")
    simulate:   bool          = Field(False, description="Force simulation mode (no hardware required)")


class StartMotorRequest(BaseModel):
    direction:  Literal["forward", "reverse"] = Field("forward", description="Motor direction")
    frequency:  Optional[float] = Field(None, ge=0.5, le=50.0, description="Set frequency in Hz (0.5–50 Hz)")
    target_rpm: Optional[float] = Field(None, gt=0, description="Target RPM (alternative to frequency)")


class SetFrequencyRequest(BaseModel):
    frequency: Optional[float] = Field(None, ge=0.5, le=50.0, description="Target frequency in Hz")
    target_rpm: Optional[float] = Field(None, gt=0, description="Target RPM (alternative to frequency)")


class SetOCThresholdRequest(BaseModel):
    threshold_amps: float = Field(..., gt=0, description="Overcurrent threshold in Amperes")


class HistoryQueryParams(BaseModel):
    start_ts: Optional[float] = Field(None, description="Start Unix timestamp")
    end_ts:   Optional[float] = Field(None, description="End Unix timestamp")
    limit:    int             = Field(1000, ge=1, le=10000)


# ── Response Models ───────────────────────────────────────────────────────────

class CommandResponse(BaseModel):
    success: bool
    message: str
    error:   Optional[str] = None
    data:    Optional[dict] = None


class StatusResponse(BaseModel):
    vfd_connected:   bool
    pzem_connected:  bool
    motor_state:     str
    oc_threshold:    float
    simulation_mode: bool
    ws_monitor_clients: int
    ws_alert_clients:   int
    timestamp:       float = Field(default_factory=time.time)


class VFDData(BaseModel):
    set_freq:  Optional[float] = None
    out_freq:  Optional[float] = None
    out_volt:  Optional[float] = None
    out_curr:  Optional[float] = None
    motor_rpm: Optional[int]   = None
    power:     Optional[float] = None
    pf:        Optional[float] = None
    voltage:   Optional[float] = None
    current:   Optional[float] = None
    inp_volt:  Optional[float] = None
    prox_rpm:  Optional[float] = None
    prox_hz:   Optional[float] = None
    phase_r:   Optional[float] = None
    phase_y:   Optional[float] = None
    phase_b:   Optional[float] = None
    source:    Optional[str]   = None


class PZEMData(BaseModel):
    voltage:  Optional[float] = None
    current:  Optional[float] = None
    power:    Optional[float] = None
    energy:   Optional[float] = None
    freq:     Optional[float] = None
    pf:       Optional[float] = None


class MonitorResponse(BaseModel):
    timestamp:   float
    motor_state: str
    vfd:         Optional[VFDData]  = None
    pzem:        Optional[PZEMData] = None
    vfd_error:   Optional[str]      = None


class AlertModel(BaseModel):
    id:           str
    type:         str
    message:      str
    severity:     str
    timestamp:    float
    acknowledged: bool
    data:         dict
