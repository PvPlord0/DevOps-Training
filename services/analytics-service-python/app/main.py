from fastapi import FastAPI, HTTPException

from .redis_client import read_snapshot

app = FastAPI(title="analytics-service")


@app.get("/health")
def health():
    return {"status": "ok"}


@app.get("/api/analytics/summary")
def summary():
    snapshot = read_snapshot()
    if snapshot is None:
        raise HTTPException(
            status_code=503,
            detail="no analytics snapshot yet -- run the analytics job at least once",
        )
    return snapshot
