"""Background job: computes a fresh analytics snapshot and writes it to
Redis. Run this manually or on a repeating schedule -- how you schedule it
changes across the project's phases, but this script itself does not."""

import logging

from app.redis_client import write_snapshot
from app.snapshot import compute_snapshot

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("analytics-job")


def main():
    logger.info("computing analytics snapshot")
    snapshot = compute_snapshot()
    write_snapshot(snapshot)
    logger.info(
        "snapshot written: %d events, %d days of bookings data",
        len(snapshot["eventsTable"]),
        len(snapshot["bookingsTimeseries"]),
    )


if __name__ == "__main__":
    main()
