# Auth service (Node.js / Express / PostgreSQL)

## Run natively

```bash
cp .env.example .env      # then edit as needed
npm install
npm start
```

Requires a running PostgreSQL instance matching the values in `.env`.

## Endpoints

See `docs/API_CONTRACT.md` at the repo root.

## Known starting point

This service intentionally does not run correctly out of the box. Part of
phase 1 is finding out why and fixing it — check the logs when `/login`
fails.
