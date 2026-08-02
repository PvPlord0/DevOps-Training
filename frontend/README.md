# Frontend (React + Vite)

## Run natively

```bash
cp .env.example .env
npm install
npm run dev
```

Talks to the gateway URL from `window.__ENV__.API_BASE_URL` (see
`public/config.js`), falling back to `VITE_API_BASE_URL` at build time if
that's not set. Keep using this pattern rather than hardcoding the API URL
in your components -- it matters more in a later phase of this project.
