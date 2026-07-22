# OpenNutriTracker AI backend

FastAPI service for the AI layer described in [`../docs/ai_plan.md`](../docs/ai_plan.md).

The first vertical slice provides:

- `GET /health` with SQLite readiness.
- `POST /api/v1/analyze/text` for structured food and portion extraction.
- Per-request OpenAI BYOK through `X-OpenAI-API-Key`, with an optional server key fallback.
- Fail-closed production Bearer authentication and per-client rate limiting.
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
  -H "Authorization: Bearer $ONT_AI_ACCESS_TOKEN" \
  -H "X-OpenAI-API-Key: $OPENAI_API_KEY" \
  -d '{"text":"190g rice, 100g chicken and one katori curd","locale":"en-IN"}'
```

The request key is passed directly to an in-memory OpenAI client. It is not written to SQLite or logs. For a
single-user self-hosted deployment, set `ONT_AI_OPENAI_API_KEY` in `backend/.env` instead and omit the header.

Production deployments must also configure a separate, randomly generated `ONT_AI_ACCESS_TOKEN`. The Flutter
client stores this application token in platform secure storage and sends it as `Authorization: Bearer <token>`.
The token is not an OpenAI key and should be rotated independently.

```bash
python -c 'import secrets; print(secrets.token_urlsafe(32))'
```

The built-in limiter defaults to 20 AI requests per client IP per minute. It protects a single warm process; add
a Vercel Firewall rule or a shared Redis-backed limiter before operating multiple instances at public scale.

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

## Serverless deployment

Serverless runtimes such as Vercel mount the application under a read-only directory (commonly `/var/task`).
The backend automatically places its transient SQLite readiness database in the runtime's writable temporary
directory when it detects Vercel or AWS Lambda. The service does not currently persist meal descriptions or AI
responses, so losing this temporary file between cold starts does not lose user data.

If the deployment explicitly defines `ONT_AI_DATABASE_URL`, it overrides that automatic default. Use this value
for a serverless deployment without a persistent database volume:

```text
sqlite+aiosqlite:////tmp/opennutritracker_ai.db
```

For a container host with a persistent disk mounted at `/data`, use
`sqlite+aiosqlite:////data/opennutritracker_ai.db` instead.
