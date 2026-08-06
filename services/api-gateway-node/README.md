# API Gateway (Node.js/Express)

Single entry point for all frontend API calls. Routes requests to the
appropriate backend service.

## Routes

| Path prefix | Target | Port |
|---|---|---|
| `/api/catalog` | Legacy Catalog (Java) | 8081 |
| `/api/auth` | Auth (Node.js) | 8082 |
| `/api/bookings` | Booking (Python) | 8083 |
| `/api/analyze` | AI Insight (Python) | 8084 |
| `/api/analytics` | Analytics (Python) | 8085 |

## Run

```bash
cp .env.example .env
npm install
npm start
```

Runs on port 8080 by default.
