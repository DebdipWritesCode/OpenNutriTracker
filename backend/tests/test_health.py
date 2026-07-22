from httpx import AsyncClient


async def test_health_reports_database_readiness(client: AsyncClient) -> None:
    response = await client.get("/health")

    assert response.status_code == 200
    assert response.json() == {
        "status": "ok",
        "service": "OpenNutriTracker AI",
        "version": "0.1.0",
        "environment": "test",
        "database": "ok",
    }
    assert response.headers["x-request-id"]


async def test_openapi_exposes_initial_endpoints(client: AsyncClient) -> None:
    response = await client.get("/openapi.json")

    assert response.status_code == 200
    paths = response.json()["paths"]
    assert "/health" in paths
    assert "/api/v1/analyze/text" in paths


async def test_cors_preflight_allows_byok_header(client: AsyncClient) -> None:
    response = await client.options(
        "/api/v1/analyze/text",
        headers={
            "Origin": "http://localhost:3000",
            "Access-Control-Request-Method": "POST",
            "Access-Control-Request-Headers": "authorization,x-openai-api-key,content-type",
        },
    )

    assert response.status_code == 200
    assert response.headers["access-control-allow-origin"] == "http://localhost:3000"
    assert "X-OpenAI-API-Key" in response.headers["access-control-allow-headers"]
    assert "Authorization" in response.headers["access-control-allow-headers"]
