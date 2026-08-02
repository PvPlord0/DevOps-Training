import os

import httpx


async def analyze_with_ollama(text: str) -> dict | None:
    """Returns None if Ollama is unreachable or misconfigured, so callers
    can fall back cleanly instead of the whole request failing."""
    base_url = os.environ.get("OLLAMA_URL")
    model = os.environ.get("OLLAMA_MODEL", "llama3.2:1b")
    if not base_url:
        return None

    prompt = (
        "Classify the sentiment of this review as exactly one word "
        "(positive, neutral, or negative), then a one-sentence summary. "
        f"Review: {text}"
    )
    try:
        async with httpx.AsyncClient(timeout=15.0) as client:
            resp = await client.post(
                f"{base_url}/api/generate",
                json={"model": model, "prompt": prompt, "stream": False},
            )
            resp.raise_for_status()
            raw = resp.json().get("response", "")
    except Exception:
        return None

    # Minimal, forgiving parse -- teams should improve this as part of the
    # real Ollama integration bonus item.
    lowered = raw.lower()
    if "positive" in lowered:
        sentiment = "positive"
    elif "negative" in lowered:
        sentiment = "negative"
    else:
        sentiment = "neutral"
    return {"sentiment": sentiment, "summary": raw.strip()[:200]}
