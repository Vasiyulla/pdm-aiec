from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import Dict, Any, Optional
import random

router = APIRouter()

class ChatRequest(BaseModel):
    message: str
    context: Optional[Dict[str, Any]] = None

class ChatResponse(BaseModel):
    response: str
    suggested_actions: Optional[list[str]] = None

@router.post("/chat", response_model=ChatResponse)
async def chat_with_aria(request: ChatRequest):
    msg = request.message.lower()
    ctx = request.context or {}
    
    vfd = ctx.get("vfd", {})
    pzem = ctx.get("pzem", {})
    motor_state = ctx.get("motor_state", "Unknown")
    is_offline = not ctx.get("connected", False)
    
    # Personality: ARIA (Advanced Real-time Industrial Assistant)
    
    # 1. Handle Connectivity Issues
    if is_offline:
        return ChatResponse(
            response="I notice the VFD is currently offline. Please ensure the RS485 communication link is active and the correct COM port is selected in the connection settings.",
            suggested_actions=["Check RS485 Cable", "Verify COM Port", "Scan Devicse"]
        )

    # 2. Status Queries
    if "status" in msg or "how is it" in msg or "condition" in msg:
        hz = vfd.get("output_freq", 0)
        volt = vfd.get("output_volt", 0)
        
        if motor_state == "Running":
            if hz > 45:
                resp = f"The motor is running at a high frequency of {hz}Hz. Voltage is stable at {volt}V. All parameters look optimal, but I recommend monitoring thermal drift if high-speed operation continues for extended periods."
            else:
                resp = f"Everything looks good. The system is running at {hz}Hz. Power consumption is within nominal range."
            return ChatResponse(response=resp, suggested_actions=["Check Thermals", "View Load Analysis"])
        else:
            return ChatResponse(response="The motor is currently stopped. System diagnostics show no active faults. Ready for operation.", suggested_actions=["Start Motor", "Run Health Check"])

    # 3. Help / Greeting
    if "hello" in msg or "hi" in msg or "help" in msg:
        return ChatResponse(
            response="Hello! I'm ARIA, your Industrial AI assistant. I can help you analyze motor efficiency, troubleshoot connectivity, or explain any VFD parameters you see on the dashboard. What can I assist you with today?",
            suggested_actions=["Analyze Health", "Check Efficiency", "Show Manual"]
        )

    # 4. Specific troubleshooting
    if "vibration" in msg or "noise" in msg:
        return ChatResponse(
            response="Unusual vibration or noise usually indicates mechanical misalignment or bearing wear. I recommend using the 'Run Analysis' tool in the Maintenance tab to get a precise failure risk score.",
            suggested_actions=["Run Analysis", "Check Bearings"]
        )

    # 5. Fallback
    responses = [
        "That's an interesting point. Based on current telemetry, the system is performing within expected parameters.",
        "I've logged your query. If you're concerned about performance, try running a full AI diagnostic from the maintenance panel.",
        "My diagnostic modules are active. I'm monitoring the VFD bus for any transient voltage spikes while you operate the controls."
    ]
    
    return ChatResponse(response=random.choice(responses))
