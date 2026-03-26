"""Ports router — GET /api/ports"""

from fastapi import APIRouter
import platform

router = APIRouter()


@router.get("/ports")
async def list_ports():
    """List available serial ports on the host machine."""
    try:
        import serial.tools.list_ports
        ports = [
            {"device": p.device, "description": p.description or ""}
            for p in serial.tools.list_ports.comports()
        ]
    except ImportError:
        if platform.system() == "Windows":
            ports = [{"device": f"COM{i}", "description": ""} for i in range(1, 20)]
        else:
            ports = [
                {"device": "/dev/ttyUSB0", "description": "USB Serial"},
                {"device": "/dev/ttyUSB1", "description": "USB Serial"},
                {"device": "/dev/ttyACM0", "description": "ACM device"},
            ]
    return {"ports": ports, "count": len(ports)}
