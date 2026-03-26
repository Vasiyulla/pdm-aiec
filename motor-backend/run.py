#!/usr/bin/env python
"""
Entry point for the backend.
Can be run directly or bundled with PyInstaller.
"""
import uvicorn
import multiprocessing
from app.main import app

if __name__ == "__main__":
    # Required for multiprocessing in frozen apps (if any)
    multiprocessing.freeze_support()
    
    uvicorn.run(
        app,
        host="127.0.0.1",
        port=8000,
        log_level="info",
        reload=False, # Must be False for packaged apps
    )

