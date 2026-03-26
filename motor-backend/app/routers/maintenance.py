from fastapi import APIRouter, HTTPException
from typing import Dict, List, Optional
import datetime
from pydantic import BaseModel
from app.services.agents.orchestrator import AgentOrchestrator

router = APIRouter(prefix="/predictive", tags=["Predictive Maintenance"])
orchestrator = AgentOrchestrator()

class SensorInput(BaseModel):
    machine_id: str
    temperature: float
    vibration: float
    pressure: float
    rpm: float

@router.post("/analyze")
async def analyze_machine_status(input_data: SensorInput):
    """
    Triggers the full AI agent pipeline for a machine.
    """
    try:
        data = {
            "temperature": input_data.temperature,
            "vibration": input_data.vibration,
            "pressure": input_data.pressure,
            "rpm": input_data.rpm
        }
        result = orchestrator.analyze_machine(input_data.machine_id, data)
        return result
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/machines")
async def get_machines():
    """
    Returns a list of monitored machines with their basic metadata.
    """
    # Placeholder for actual DB query
    return [
        {"id": "M-001", "name": "VFD Motor A", "type": "AC Motor", "location": "Floor 1", "status": "Active"},
        {"id": "M-002", "name": "VFD Motor B", "type": "AC Motor", "location": "Floor 2", "status": "Maintenance Required"},
        {"id": "M-003", "name": "Pump Delta", "type": "Hydraulic Pump", "location": "Floor 1", "status": "Idle"}
    ]

@router.get("/history/{machine_id}")
async def get_machine_history(machine_id: str):
    """
    Returns the last 10 prediction results for a specific machine.
    """
    # Placeholder for historical data
    return [
        {"timestamp": (datetime.datetime.now() - datetime.timedelta(hours=i)).isoformat(), 
         "risk_level": "Low", "failure_probability": 0.05}
        for i in range(10)
    ]
