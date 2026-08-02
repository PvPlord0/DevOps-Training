# AI Insight service (Python / FastAPI / Ollama)

## Run natively

```bash
cp .env.example .env
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --host 0.0.0.0 --port 8084 --reload
```

Works with no LLM running at all -- it falls back to a simple rule-based
sentiment check so the contract in `docs/API_CONTRACT.md` is always
satisfied. Wiring up a real local model via Ollama is optional for this
phase, but the endpoint contract must behave the same either way.

To try the real path locally: install Ollama, run `ollama pull llama3.2:1b`,
start it, and set `OLLAMA_URL=http://localhost:11434` in `.env`.
