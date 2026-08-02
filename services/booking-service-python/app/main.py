import uuid
from datetime import datetime, timezone

from fastapi import FastAPI, HTTPException

from .ai_client import analyze_review
from .db import get_db
from .events import publish_booking_created
from .models import BookingRequest, ReviewRequest

app = FastAPI(title="booking-service")


def _now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


@app.get("/health")
def health():
    return {"status": "ok"}


@app.post("/api/bookings", status_code=201)
def create_booking(payload: BookingRequest):
    db = get_db()
    booking = {
        "id": str(uuid.uuid4()),
        "userId": payload.userId,
        "eventId": payload.eventId,
        "status": "confirmed",
        "createdAt": _now_iso(),
    }
    db.bookings.insert_one(dict(booking))
    publish_booking_created(booking)
    return booking


@app.get("/api/bookings")
def list_bookings(since: str | None = None):
    """Used by the analytics job. `since` is an optional ISO8601 timestamp
    to only fetch bookings created after that point."""
    db = get_db()
    query = {}
    if since:
        query["createdAt"] = {"$gte": since}
    bookings = list(db.bookings.find(query, {"_id": 0}))
    return bookings


@app.get("/api/bookings/{booking_id}")
def get_booking(booking_id: str):
    db = get_db()
    booking = db.bookings.find_one({"id": booking_id}, {"_id": 0})
    if not booking:
        raise HTTPException(status_code=404, detail="booking not found")
    return booking


@app.post("/api/bookings/{booking_id}/review", status_code=201)
async def create_review(booking_id: str, payload: ReviewRequest):
    db = get_db()
    booking = db.bookings.find_one({"id": booking_id}, {"_id": 0})
    if not booking:
        raise HTTPException(status_code=404, detail="booking not found")

    analysis = await analyze_review(payload.text)
    review = {
        "id": str(uuid.uuid4()),
        "bookingId": booking_id,
        "eventId": booking["eventId"],
        "text": payload.text,
        "sentiment": analysis.get("sentiment", "neutral"),
        "summary": analysis.get("summary", ""),
        "createdAt": _now_iso(),
    }
    db.reviews.insert_one(dict(review))
    return review


@app.get("/api/reviews")
def list_reviews(since: str | None = None):
    """Used by the analytics job."""
    db = get_db()
    query = {}
    if since:
        query["createdAt"] = {"$gte": since}
    reviews = list(db.reviews.find(query, {"_id": 0}))
    return reviews
