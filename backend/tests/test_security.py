from collections.abc import AsyncIterator
from contextlib import asynccontextmanager
from pathlib import Path

from httpx import ASGITransport, AsyncClient

from app.config import Settings
from app.main import create_app
from app.schemas.analysis import AnalyzeTextRequest, MealExtraction
from app.services import MealAnalysisResult


class StubMealAnalysisService:
    async def analyze_text(
        self,
        request: AnalyzeTextRequest,
        request_api_key: str | None,
    ) -> MealAnalysisResult:
        return MealAnalysisResult(
            extraction=MealExtraction(foods=[], notes=[]),
            model_used="test-model",
        )


@asynccontextmanager
async def _production_client(
    tmp_path: Path,
    *,
    access_token: str | None,
    rate_limit_requests: int = 20,
) -> AsyncIterator[AsyncClient]:
    settings = Settings(
        environment="production",
        database_url=f"sqlite+aiosqlite:///{tmp_path / 'security.db'}",
        access_token=access_token,
        openai_api_key="sk-server-not-real",
        rate_limit_requests=rate_limit_requests,
        rate_limit_window_seconds=60,
    )
    app = create_app(settings)
    app.state.meal_analysis_service = StubMealAnalysisService()
    async with app.router.lifespan_context(app):
        async with AsyncClient(
            transport=ASGITransport(app=app),
            base_url="http://test",
        ) as client:
            yield client


async def test_production_fails_closed_without_access_token(tmp_path: Path) -> None:
    async with _production_client(tmp_path, access_token=None) as client:
        response = await client.post(
            "/api/v1/analyze/text",
            json={"text": "100g rice"},
        )

    assert response.status_code == 503
    assert response.json()["error"]["code"] == "security_not_configured"


async def test_production_requires_valid_bearer_token(tmp_path: Path) -> None:
    async with _production_client(tmp_path, access_token="correct-token") as client:
        missing = await client.post(
            "/api/v1/analyze/text",
            json={"text": "100g rice"},
        )
        invalid = await client.post(
            "/api/v1/analyze/text",
            headers={"Authorization": "Bearer wrong-token"},
            json={"text": "100g rice"},
        )
        valid = await client.post(
            "/api/v1/analyze/text",
            headers={"Authorization": "Bearer correct-token"},
            json={"text": "100g rice"},
        )

    assert missing.status_code == 401
    assert missing.json()["error"]["code"] == "access_token_required"
    assert invalid.status_code == 401
    assert invalid.json()["error"]["code"] == "invalid_access_token"
    assert valid.status_code == 200


async def test_rate_limit_returns_retry_after(tmp_path: Path) -> None:
    headers = {
        "Authorization": "Bearer correct-token",
        "X-Forwarded-For": "203.0.113.10",
    }
    async with _production_client(
        tmp_path,
        access_token="correct-token",
        rate_limit_requests=2,
    ) as client:
        first = await client.post(
            "/api/v1/analyze/text",
            headers=headers,
            json={"text": "100g rice"},
        )
        second = await client.post(
            "/api/v1/analyze/text",
            headers=headers,
            json={"text": "100g rice"},
        )
        limited = await client.post(
            "/api/v1/analyze/text",
            headers=headers,
            json={"text": "100g rice"},
        )

    assert first.status_code == 200
    assert second.status_code == 200
    assert limited.status_code == 429
    assert limited.json()["error"]["code"] == "rate_limit_exceeded"
    assert int(limited.headers["retry-after"]) >= 1
