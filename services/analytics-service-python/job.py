"""Background job: computes a fresh analytics snapshot and writes it to
Redis. Run this manually or on a repeating schedule -- how you schedule it
changes across the project's phases, but this script itself does not."""

import logging
import sys
sys.path.insert(0, '/app/src')
from dotenv import load_dotenv

load_dotenv()

from redis_client import write_snapshot
from snapshot import compute_snapshot
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
