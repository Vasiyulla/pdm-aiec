"""
Database Layer — async SQLite (aiosqlite)
=========================================
Tables:
  readings   — every 500 ms poll snapshot
  alerts     — all generated alerts (mirrored from alert engine)
  events     — user-triggered events (start/stop/connect etc.)
"""

from __future__ import annotations

import aiosqlite
import logging
import os
import time
from typing import Optional

logger = logging.getLogger("motor.db")

DB_PATH = os.environ.get("MOTOR_DB_PATH", "motor_data.db")


async def init_db():
    async with aiosqlite.connect(DB_PATH) as db:
        await db.execute("""
            CREATE TABLE IF NOT EXISTS readings (
                id          INTEGER PRIMARY KEY AUTOINCREMENT,
                ts          REAL    NOT NULL,
                motor_state TEXT,
                -- VFD fields
                set_freq    REAL,
                out_freq    REAL,
                out_volt    REAL,
                out_curr    REAL,
                motor_rpm   INTEGER,
                vfd_source  TEXT,
                -- PZEM fields
                voltage     REAL,
                current     REAL,
                power       REAL,
                energy      REAL,
                frequency   REAL,
                pf          REAL
            )
        """)
        await db.execute("""
            CREATE TABLE IF NOT EXISTS alerts (
                id          TEXT    PRIMARY KEY,
                ts          REAL    NOT NULL,
                type        TEXT,
                message     TEXT,
                severity    TEXT,
                acknowledged INTEGER DEFAULT 0,
                data_json   TEXT
            )
        """)
        await db.execute("""
            CREATE TABLE IF NOT EXISTS events (
                id          INTEGER PRIMARY KEY AUTOINCREMENT,
                ts          REAL    NOT NULL,
                category    TEXT,
                message     TEXT
            )
        """)
        # Indexes for time-range queries
        await db.execute("CREATE INDEX IF NOT EXISTS ix_readings_ts ON readings(ts)")
        await db.execute("CREATE INDEX IF NOT EXISTS ix_alerts_ts   ON alerts(ts)")
        await db.execute("CREATE INDEX IF NOT EXISTS ix_events_ts   ON events(ts)")
        await db.commit()
    logger.info("Database initialised: %s", DB_PATH)


async def save_reading(data: dict):
    vfd  = data.get("vfd")  or {}
    pzem = data.get("pzem") or {}
    async with aiosqlite.connect(DB_PATH) as db:
        await db.execute("""
            INSERT INTO readings
              (ts, motor_state, set_freq, out_freq, out_volt, out_curr,
               motor_rpm, vfd_source, voltage, current, power, energy,
               frequency, pf)
            VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?)
        """, (
            data.get("timestamp", time.time()),
            data.get("motor_state"),
            vfd.get("set_freq"),
            vfd.get("out_freq"),
            vfd.get("out_volt"),
            vfd.get("out_curr"),
            vfd.get("motor_rpm"),
            vfd.get("source"),
            pzem.get("voltage"),
            pzem.get("current"),
            pzem.get("power"),
            pzem.get("energy"),
            pzem.get("freq"),
            pzem.get("pf"),
        ))
        await db.commit()


async def log_event(category: str, message: str):
    async with aiosqlite.connect(DB_PATH) as db:
        await db.execute(
            "INSERT INTO events (ts, category, message) VALUES (?,?,?)",
            (time.time(), category, message)
        )
        await db.commit()


async def get_history(
    start_ts: Optional[float] = None,
    end_ts:   Optional[float] = None,
    limit:    int = 1000,
) -> list[dict]:
    start_ts = start_ts or (time.time() - 3600)   # default: last 1 hour
    end_ts   = end_ts   or time.time()

    async with aiosqlite.connect(DB_PATH) as db:
        db.row_factory = aiosqlite.Row
        cursor = await db.execute("""
            SELECT * FROM readings
            WHERE ts BETWEEN ? AND ?
            ORDER BY ts DESC
            LIMIT ?
        """, (start_ts, end_ts, limit))
        rows = await cursor.fetchall()
    return [dict(r) for r in rows]


async def get_events(limit: int = 100) -> list[dict]:
    async with aiosqlite.connect(DB_PATH) as db:
        db.row_factory = aiosqlite.Row
        cursor = await db.execute(
            "SELECT * FROM events ORDER BY ts DESC LIMIT ?", (limit,)
        )
        rows = await cursor.fetchall()
    return [dict(r) for r in rows]


async def get_report_data(start_ts: float, end_ts: float) -> list[dict]:
    """Fetch all readings in a time range for CSV export."""
    async with aiosqlite.connect(DB_PATH) as db:
        db.row_factory = aiosqlite.Row
        cursor = await db.execute("""
            SELECT * FROM readings
            WHERE ts BETWEEN ? AND ?
            ORDER BY ts ASC
        """, (start_ts, end_ts))
        rows = await cursor.fetchall()
    return [dict(r) for r in rows]
