# Phase 1 Bug Fixes & Notes

## Environment

- **Node version:** 24.18.1
- **npm version:** 11.16.0
- **Python version (required):** 3.12.11
- **OpenJDK:** 21.0.11
- **Go version:** 1.24.4

## Summary

| # | Bug | Service |
|---|-----|---------|
| 1 | JWT_SECRET typo (`JWT_SECERT`) | auth-service-node |
| 2 | Missing dotenv loading | auth-service-node (Node) |
| 3 | Missing dotenv loading | ai-insight, analytics, booking (Python) |
| 4 | Missing `/health` in API-CONTRACT.md | legacy-catalog-java |
| 5 | Vite/esbuild compatibility | frontend |
| 6 | Frontend routing — missing API Gateway | frontend |
| 7 | Missing try/catch in `/login` handler | auth-service-node |
| 8 | Missing JWT_SECRET fail-fast check | auth-service-node |
| 9 | `express.json()` consumes body before proxy | api-gateway-node |
| 10 | Published event uses `id` instead of `bookingId` | booking-service-python |

---

## Bug 1: JWT_SECRET Typo

**Location:** `services/auth-service-node/src/routes/auth.js:39`

**Description:** Environment variable name misspelled as `JWT_SECERT` instead of `JWT_SECRET` (8th and 9th letters replaced). This caused JWT token signing to fail or use `undefined` as the secret.

**Fix:** Changed `process.env.JWT_SECERT` → `process.env.JWT_SECRET`

---

## Bug 2: Missing dotenv — Node Auth Service

**Location:** `services/auth-service-node/src/index.js`

**Description:** Node auth service was not loading `.env` files, so environment variables were unavailable.

**Fix:**
1. Added `dotenv` package to `package.json`
2. Added `require('dotenv').config();` at top of `index.js`

---

## Bug 3: Missing dotenv — Python Services

**Locations:**
- `services/ai-insight-service-python/app/main.py`
- `services/analytics-service-python/app/main.py`
- `services/analytics-service-python/job.py`
- `services/booking-service-python/app/main.py`

**Description:** Python services were not loading `.env` files, so environment variables were unavailable at runtime.

**Fix:**
1. Added `python-dotenv==1.2.2` to each `requirements.txt`
2. Added `from dotenv import load_dotenv` + `load_dotenv()` in each `main.py`/`job.py`

---

## Bug 4: Missing `/health` in API-CONTRACT.md

**Location:** `services/legacy-catalog-java/src/main/java/com/campus/catalog/health/`

**Description:** Health check endpoint was not documented in `API-CONTRACT.md` but was required for service health monitoring.

**Fix:** Added `/health` endpoint to the legacy catalog Java service.

---

## Bug 5: Frontend Vite/Esbuild Compatibility

**Location:** `frontend/package.json`

**Description:** Outdated Vite version which had a version of esbuild with 2 vulnerabilities.

**Fix:**
1. Upgraded `vite: ^5.2.11 → ^7.3.6`
2. Added `allowScripts` entry for `esbuild@0.28.1`

---

## Bug 6: Frontend Routing — Missing API Gateway

**Location:** `services/api-gateway-node/`

**Description:** Frontend routing was broken because there was no API Gateway to proxy external requests to internal services.

**Fix:** Created `services/api-gateway-node/` as a Node.js API Gateway to handle frontend routing.

---

## Bug 7: Missing try/catch in `/login` Handler

**Location:** `services/auth-service-node/src/routes/auth.js:28-43`

**Description:** Async `/login` handler had no `try/catch`. Any error (DB down, missing `JWT_SECRET`) became an unhandled rejection that crashed the process.

**Fix:** Wrapped handler body in `try/catch` to return `500` on failure, matching `/register`.

---

## Bug 8: Missing JWT_SECRET Fail-Fast Check

**Location:** `services/auth-service-node/src/index.js:1-3`

**Description:** The service didn't validate `JWT_SECRET` at startup. If unset, `jwt.sign()` would throw during login, crashing the process.

**Fix:** Added a startup check that throws immediately if `JWT_SECRET` is missing.

---

## Bug 9: `express.json()` Consumes Body Before Proxy

**Location:** `services/api-gateway-node/src/index.js:8`

**Description:** `express.json()` ran before the proxy middleware, draining the request stream. Every POST through the gateway arrived at the backend with an empty body.

**Fix:** Removed `express.json()` from the gateway. The gateway only proxies — it never needs to parse request bodies itself.

---

## Bug 10: Published Event Uses `id` Instead of `bookingId`

**Location:** `services/booking-service-python/app/events.py:24`

**Description:** Booking service published with key `"id"`, but the notification worker expects `"bookingId"`. Worker always received an empty booking ID. — producing broken log output like `"notification: booking  confirmed for user ..."`.

**Fix:** Before publishing, rename the `"id"` key to `"bookingId"` in the message dict so it matches the Go struct tag and the API contract (`API_CONTRACT.md:35`).
