# Phase 1 Bug Fixes & Notes

## Environment

- **Node version:** 24.18.1
- **npm version:** 11.16.0
- **Python version (required):** 3.12.11
- **OpenJDK:** 21.0.11

## Summary

| # | Bug | Service |
|---|-----|---------|
| 1 | JWT_SECRET typo (`JWT_SECERT`) | auth-service-node |
| 2 | Missing dotenv loading | auth-service-node (Node) |
| 3 | Missing dotenv loading | ai-insight, analytics, booking (Python) |
| 4 | Missing `/health` in API-CONTRACT.md | legacy-catalog-java |

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
