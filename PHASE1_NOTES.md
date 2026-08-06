# Phase 1 Bug Fixes & Notes

## Environment

- **Node version:** 24.18.1
- **npm version:** 11.16.0

## Summary

| # | Bug | Service |
|---|-----|---------|
| 1 | JWT_SECRET typo (`JWT_SECERT`) | auth-service-node |
| 2 | Missing dotenv loading | auth-service-node (Node) |

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

