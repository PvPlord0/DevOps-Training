# EventHub — Project Starter

A polyglot microservices platform. This is your **starting point** for a
multi-phase project — this package covers phase 1 only. Further phases and
their instructions will be provided once phase 1 is complete.

## What this system does

EventHub is a small event booking platform: users register/log in, browse a
catalog of events, book a spot, get an async notification, and see an
AI-generated sentiment summary on reviews.

## Services

| Service | Language | Datastore | Port |
|---|---|---|---|
| `frontend` | React | — | 3000 |
| `services/legacy-catalog-java` | Java (Spring Boot) | MySQL | 8081 |
| `services/auth-service-node` | Node.js (Express) | PostgreSQL | 8082 |
| `services/booking-service-python` | Python (FastAPI) | MongoDB | 8083 |
| `services/notification-worker-go` | Go | — (consumes RabbitMQ) | — |
| `services/ai-insight-service-python` | Python (FastAPI) + Ollama | — (local model) | 8084 |
| `services/analytics-service-python` | Python (FastAPI + background job) | Redis | 8085 |

## Repo layout

```
docs/          read this first — API contract
services/      each microservice, runnable natively
frontend/      the React SPA
db-seed/       seed scripts for each database
```

## Start here

1. Read `docs/PHASE1.md` — this defines what you build and what "done"
   means for this phase.
2. Read `docs/ARCHITECTURE.md` for how the pieces fit together.
3. Read `docs/API_CONTRACT.md` for how the services talk to each other.
4. Each `services/<name>/README.md` has exact run instructions for that
   service. Get all of them running before you move on.

## Rules

- You may add libraries, restructure internals, and refactor freely — the
  external API contract in `docs/API_CONTRACT.md` is the one thing that
  must stay stable, since other services and the frontend depend on it.
- Something in this repo is broken on purpose. Finding and fixing it is
  part of this phase.
