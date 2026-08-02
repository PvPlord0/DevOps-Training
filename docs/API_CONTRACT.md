# API contract (v1)

This is the stable contract between services and the frontend. You may
refactor internals freely, but requests/responses shaped like this must keep
working, since other teams' components (and the frontend) depend on them.

## Auth service — `services/auth-service-node` (port 8082)

| Method | Path | Body | Response |
|---|---|---|---|
| POST | `/api/auth/register` | `{ "email": str, "password": str }` | `{ "id": str, "email": str }` |
| POST | `/api/auth/login` | `{ "email": str, "password": str }` | `{ "token": str }` |
| GET | `/health` | — | `{ "status": "ok" }` |

Other services validate the JWT from the `Authorization: Bearer <token>`
header. Token payload includes `sub` (user id) and `email`.

## Legacy catalog service — `services/legacy-catalog-java` (port 8081)

| Method | Path | Body | Response |
|---|---|---|---|
| GET | `/api/catalog` | — | `[{ "id": int, "title": str, "price": number }]` |
| GET | `/api/catalog/{id}` | — | `{ "id": int, "title": str, "price": number }` |
| GET | `/health` | — | `{ "status": "ok" }` |

## Booking service — `services/booking-service-python` (port 8083)

| Method | Path | Body | Response |
|---|---|---|---|
| POST | `/api/bookings` | `{ "userId": str, "eventId": int }` | `{ "id": str, "status": "confirmed" }` |
| GET | `/api/bookings/{id}` | — | booking document |
| GET | `/health` | — | `{ "status": "ok" }` |

On successful booking, this service publishes a message to the `bookings`
queue/topic: `{ "bookingId": str, "userId": str, "eventId": int }`. The
notification worker consumes this.

## AI Insight service — `services/ai-insight-service-python` (port 8084)

| Method | Path | Body | Response |
|---|---|---|---|
| POST | `/api/analyze` | `{ "text": str }` | `{ "sentiment": "positive"\|"neutral"\|"negative", "summary": str }` |
| GET | `/health` | — | `{ "status": "ok" }` |

Falls back to a rule-based response if `OLLAMA_URL` is unset or unreachable
— the endpoint contract stays the same either way.

## Booking service — additions

| Method | Path | Body | Response |
|---|---|---|---|
| GET | `/api/bookings` | — (optional `?since=<ISO8601>`) | `[booking, ...]` |
| POST | `/api/bookings/{id}/review` | `{ "text": str }` | review document, including `sentiment` |
| GET | `/api/reviews` | — (optional `?since=<ISO8601>`) | `[review, ...]` |

## Analytics service — `services/analytics-service-python` (port 8085)

| Method | Path | Body | Response |
|---|---|---|---|
| GET | `/api/analytics/summary` | — | analytics snapshot (see below) |
| GET | `/health` | — | `{ "status": "ok" }` |

This service has no write endpoints of its own -- its data is produced by
a separate background job (`job.py` in the same folder) that computes a
fresh snapshot and stores it. The API only reads and serves the latest one.

Snapshot shape:

```json
{
  "generatedAt": "2026-08-01T12:00:00+00:00",
  "eventsTable": [
    { "eventId": 1, "title": "...", "price": 15.0, "bookingsCount": 4,
      "revenue": 60.0, "reviewCount": 2, "avgSentimentScore": 0.5 }
  ],
  "bookingsTimeseries": [
    { "date": "2026-07-20", "bookings": 3 }
  ],
  "sentimentTotals": { "positive": 5, "neutral": 2, "negative": 1 }
}
```
