from fastapi import FastAPI
from pydantic import BaseModel

from .fallback import rule_based_analysis
from .ollama_client import analyze_with_ollama

app = FastAPI(title="ai-insight-service")


class AnalyzeRequest(BaseModel):
    text: str


@app.get("/health")
def health():
    return {"status": "ok"}


@app.post("/api/analyze")
async def analyze(payload: AnalyzeRequest):
    result = await analyze_with_ollama(payload.text)
    if result is None:
        result = rule_based_analysis(payload.text)
    return result
