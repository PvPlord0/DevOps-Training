# Architecture

```
Client (browser)
   -> Frontend (React)
        -> Legacy Catalog service (Java) -> MySQL
        -> Auth service (Node.js)        -> PostgreSQL
        -> Booking service (Python)      -> MongoDB
               -> publishes events -> Message broker -> Notification worker (Go)
               -> calls -> AI Insight service (Python) -> local LLM via Ollama
        -> Analytics API (Python)        -> Redis
   -> Auth & Booking also read/write a shared cache (Redis)
```

## Why each piece is here

- **Legacy catalog (Java)**: written deliberately in an old style — config
  baked into the app, older dependency versions, no health endpoint. This
  is your "inherited legacy system," not a coding exercise.
- **Auth (Node.js) / PostgreSQL**: standard relational data, JWT-based auth.
  Other services trust its tokens.
- **Booking (Python) / MongoDB**: booking documents are semi-structured, a
  natural fit for a document store. Booking creation publishes a message —
  this is your async messaging path. Booking also owns reviews: submitting
  a review calls the AI Insight service and stores the result alongside the
  review.
- **Notification worker (Go)**: pure consumer, no HTTP API of its own. It
  listens on the message broker for booking events and logs a notification
  — this proves your messaging path actually works end-to-end, not just
  that a message was sent.
- **AI Insight (Python)**: wraps a small local LLM (via Ollama) to score
  sentiment on review text. Ships with a rule-based fallback so the rest of
  the system works even before the real model is wired up.
- **Analytics service (Python)**: has two entrypoints sharing the same
  logic — a background job that reads bookings/reviews/catalog data,
  computes aggregate stats, and writes a snapshot to Redis, and a small
  read-only API that serves whatever snapshot is currently stored. The
  frontend's dashboard reads from that API.

## Data flow for the two less-obvious paths

**A booking's notification**: booking service creates a booking in MongoDB
-> publishes a message to the broker -> notification worker consumes it and
logs a confirmation. This happens asynchronously — the person booking
doesn't wait on it.

**A review's sentiment**: user submits review text to the booking service ->
booking service calls the AI Insight service synchronously -> the result
(sentiment + summary) is stored with the review in MongoDB -> later, the
analytics job reads all reviews and aggregates sentiment counts into its
snapshot -> the dashboard's pie chart reflects that.
