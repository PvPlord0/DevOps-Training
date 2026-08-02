"""Shared logic for computing the analytics snapshot. Used by both the
background job (job.py, writes the snapshot) and the read API (app/main.py,
serves it). Keeping this in one place means the job and the API can never
disagree about what a snapshot looks like."""

import os
from collections import defaultdict
from datetime import datetime, timedelta, timezone

import httpx

SENTIMENT_SCORE = {"positive": 1, "neutral": 0, "negative": -1}


def _get(url: str) -> list:
    resp = httpx.get(url, timeout=15.0)
    resp.raise_for_status()
    return resp.json()


def compute_snapshot() -> dict:
    booking_url = os.environ.get("BOOKING_SERVICE_URL", "http://localhost:8083")
    catalog_url = os.environ.get("CATALOG_SERVICE_URL", "http://localhost:8081")

    catalog = _get(f"{catalog_url}/api/catalog")
    bookings = _get(f"{booking_url}/api/bookings")
    reviews = _get(f"{booking_url}/api/reviews")

    events_by_id = {event["id"]: event for event in catalog}

    per_event = defaultdict(lambda: {
        "bookingsCount": 0,
        "revenue": 0.0,
        "sentimentCounts": {"positive": 0, "neutral": 0, "negative": 0},
    })

    for booking in bookings:
        event_id = booking["eventId"]
        event = events_by_id.get(event_id, {})
        per_event[event_id]["bookingsCount"] += 1
        per_event[event_id]["revenue"] += float(event.get("price", 0))

    for review in reviews:
        event_id = review["eventId"]
        sentiment = review.get("sentiment", "neutral")
        per_event[event_id]["sentimentCounts"][sentiment] = (
            per_event[event_id]["sentimentCounts"].get(sentiment, 0) + 1
        )

    table = []
    sentiment_totals = {"positive": 0, "neutral": 0, "negative": 0}
    for event_id, stats in per_event.items():
        event = events_by_id.get(event_id, {"title": f"Unknown event {event_id}"})
        counts = stats["sentimentCounts"]
        total_reviews = sum(counts.values())
        avg_score = (
            sum(SENTIMENT_SCORE[k] * v for k, v in counts.items()) / total_reviews
            if total_reviews else 0
        )
        for k in sentiment_totals:
            sentiment_totals[k] += counts.get(k, 0)
        table.append({
            "eventId": event_id,
            "title": event.get("title", "Unknown"),
            "price": event.get("price", 0),
            "bookingsCount": stats["bookingsCount"],
            "revenue": round(stats["revenue"], 2),
            "reviewCount": total_reviews,
            "avgSentimentScore": round(avg_score, 2),
        })

    # Bookings-per-day time series, last 14 days.
    today = datetime.now(timezone.utc).date()
    days = [(today - timedelta(days=i)) for i in range(13, -1, -1)]
    counts_by_day = defaultdict(int)
    for booking in bookings:
        created_at = booking.get("createdAt")
        if not created_at:
            continue
        day = datetime.fromisoformat(created_at.replace("Z", "+00:00")).date()
        counts_by_day[day] += 1

    timeseries = [
        {"date": day.isoformat(), "bookings": counts_by_day.get(day, 0)}
        for day in days
    ]

    return {
        "generatedAt": datetime.now(timezone.utc).isoformat(),
        "eventsTable": table,
        "bookingsTimeseries": timeseries,
        "sentimentTotals": sentiment_totals,
    }
