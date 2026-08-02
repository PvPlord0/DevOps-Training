# Booking service (Python / FastAPI / MongoDB)

## Run natively

```bash
cp .env.example .env
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --host 0.0.0.0 --port 8083 --reload
```

Requires a running MongoDB instance, and the AI Insight service reachable
at `AI_INSIGHT_URL` for review submission (it degrades to a neutral
placeholder if that service is down, rather than failing the request).
RabbitMQ is optional for phase 1 -- if `RABBITMQ_URL` isn't reachable,
booking creation still succeeds and a warning is logged.

## Endpoints

See `docs/API_CONTRACT.md` at the repo root. Note the two endpoints used by
the analytics job: `GET /api/bookings` and `GET /api/reviews`, both support
an optional `?since=<ISO8601 timestamp>` filter.
