import os

import httpx


async def analyze_review(text: str) -> dict:
    """Calls the AI Insight service. Falls back to a neutral placeholder if
    it's unreachable, so review submission never hard-fails just because
    that service is down."""
    base_url = os.environ.get("AI_INSIGHT_URL", "http://localhost:8084")
    try:
        async with httpx.AsyncClient(timeout=20.0) as client:
            resp = await client.post(f"{base_url}/api/analyze", json={"text": text})
            resp.raise_for_status()
            return resp.json()
    except Exception:
        return {"sentiment": "neutral", "summary": text.strip()[:80]}
