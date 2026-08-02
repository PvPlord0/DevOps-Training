import json
import os

import redis

_client = None


def get_client():
    global _client
    if _client is None:
        _client = redis.from_url(os.environ.get("REDIS_URL", "redis://localhost:6379/0"))
    return _client


def read_snapshot() -> dict | None:
    raw = get_client().get(os.environ.get("SNAPSHOT_KEY", "analytics:snapshot"))
    if raw is None:
        return None
    return json.loads(raw)


def write_snapshot(snapshot: dict) -> None:
    get_client().set(
        os.environ.get("SNAPSHOT_KEY", "analytics:snapshot"),
        json.dumps(snapshot),
    )
