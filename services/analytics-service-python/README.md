# Analytics service (Python / FastAPI + a background job / Redis)

This folder has **two entrypoints** sharing the same code:

- `app/main.py` -- a small read-only API, `GET /api/analytics/summary`,
  serving whatever snapshot is currently in Redis.
- `job.py` -- a script that computes a fresh snapshot (by calling the
  catalog and booking services) and writes it to Redis.

They share `app/snapshot.py` so the job and the API can never disagree
about what a snapshot contains.

## Run natively

```bash
cp .env.example .env
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt

# Terminal 1: the read API
uvicorn app.main:app --host 0.0.0.0 --port 8085 --reload

# Terminal 2: generate a snapshot (run this whenever you want fresh data --
# for now, run it manually after creating a few bookings and reviews)
python job.py
```

Requires a running Redis instance, and the catalog and booking services
(`CATALOG_SERVICE_URL`, `BOOKING_SERVICE_URL`) reachable.

## Try it end to end

1. Create a booking via the booking service.
2. Submit a review on that booking.
3. Run `python job.py`.
4. `curl http://localhost:8085/api/analytics/summary` -- you should see
   that booking and review reflected in the numbers.

If step 4 returns a 503, it means the job hasn't been run yet.
