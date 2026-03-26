"""
Reports router — GET /api/reports/export
Downloads a CSV of all readings in the requested time range.
"""

from fastapi import APIRouter, Query
from fastapi.responses import StreamingResponse
from app.db.database import get_report_data
import csv, io, time

router = APIRouter()


@router.get("/reports/export")
async def export_report(
    start_ts: float = Query(default=None, description="Start Unix timestamp"),
    end_ts:   float = Query(default=None, description="End Unix timestamp"),
):
    start = start_ts or (time.time() - 86400)   # default: last 24 h
    end   = end_ts   or time.time()

    rows = await get_report_data(start_ts=start, end_ts=end)

    def generate():
        buf = io.StringIO()
        if not rows:
            buf.write("No data in selected range\n")
            yield buf.getvalue()
            return

        writer = csv.DictWriter(buf, fieldnames=list(rows[0].keys()))
        writer.writeheader()
        for row in rows:
            # Convert unix timestamp to human-readable
            row["ts"] = time.strftime("%Y-%m-%d %H:%M:%S", time.localtime(row["ts"]))
            writer.writerow(row)
        yield buf.getvalue()

    filename = f"motor_report_{int(start)}_{int(end)}.csv"
    return StreamingResponse(
        generate(),
        media_type="text/csv",
        headers={"Content-Disposition": f'attachment; filename="{filename}"'},
    )
