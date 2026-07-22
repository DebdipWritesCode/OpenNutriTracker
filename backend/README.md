# OpenNutriTracker AI backend

FastAPI service for the AI layer described in [`../docs/ai_plan.md`](../docs/ai_plan.md).

The first vertical slice provides:

- `GET /health` with SQLite readiness.
- `POST /api/v1/analyze/text` for structured food and portion extraction.
- Per-request OpenAI BYOK through `X-OpenAI-API-Key`, with an optional server key fallback.
- `gpt-5.4-mini` as the primary model and `gpt-5.4` as the configurable fallback.
- Request IDs, structured logs, CORS, OpenAPI docs, tests, and a non-root Docker image.

The AI endpoint deliberately **does not return calories or macros**. Those values will be resolved by the
database-backed nutrition engine in a later slice.

## Local setup

```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -e '.[dev]'
cp .env.example .env
uvicorn app.main:app --reload
```

Open <http://localhost:8000/docs> or check readiness:

```bash
curl http://localhost:8000/health
```

Try text extraction with your own OpenAI key:

```bash
curl -X POST http://localhost:8000/api/v1/analyze/text \
  -H 'Content-Type: application/json' \
  -H "X-OpenAI-API-Key: $OPENAI_API_KEY" \
  -d '{"text":"190g rice, 100g chicken and one katori curd","locale":"en-IN"}'
```

The request key is passed directly to an in-memory OpenAI client. It is not written to SQLite or logs. For a
single-user self-hosted deployment, set `ONT_AI_OPENAI_API_KEY` in `backend/.env` instead and omit the header.

## Tests and quality checks

```bash
cd backend
source .venv/bin/activate
ruff check .
pytest
```

## Docker

```bash
cd backend
cp .env.example .env
docker compose up --build
```

The SQLite file lives in the named `ai-data` volume.
