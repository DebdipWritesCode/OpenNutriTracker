from httpx import AsyncClient

from app.schemas.analysis import AnalyzeTextRequest, ExtractedFood, MealExtraction
from app.services import MealAnalysisResult


class FakeMealAnalysisService:
    def __init__(self) -> None:
        self.received_key: str | None = None

    async def analyze_text(
        self,
        request: AnalyzeTextRequest,
        request_api_key: str | None,
    ) -> MealAnalysisResult:
        self.received_key = request_api_key
        assert request.locale == "en-IN"
        return MealAnalysisResult(
            extraction=MealExtraction(
                foods=[
                    ExtractedFood(
                        original_text="2 chapati",
                        canonical_name="chapati",
                        quantity=2,
                        unit="piece",
                        estimated_grams=80,
                        confidence=0.92,
                    )
                ],
                notes=[],
            ),
            model_used="gpt-5.4-mini",
        )


async def test_analyze_text_returns_editable_foods(client: AsyncClient) -> None:
    service = FakeMealAnalysisService()
    client._transport.app.state.meal_analysis_service = service  # type: ignore[attr-defined]

    response = await client.post(
        "/api/v1/analyze/text",
        headers={"X-OpenAI-API-Key": "sk-test-not-real"},
        json={"text": "2 chapati", "locale": "en-IN"},
    )

    assert response.status_code == 200
    assert service.received_key == "sk-test-not-real"
    body = response.json()
    assert body["model_used"] == "gpt-5.4-mini"
    assert body["foods"][0]["canonical_name"] == "chapati"
    assert body["foods"][0]["estimated_grams"] == 80
    assert "calories" not in body["foods"][0]


async def test_analyze_text_rejects_empty_input(client: AsyncClient) -> None:
    response = await client.post("/api/v1/analyze/text", json={"text": "  "})

    assert response.status_code == 422


async def test_analyze_text_requires_key_when_server_has_none(client: AsyncClient) -> None:
    response = await client.post(
        "/api/v1/analyze/text",
        json={"text": "190g rice"},
    )

    assert response.status_code == 401
    assert response.json()["error"]["code"] == "missing_api_key"
    assert response.json()["error"]["request_id"] == response.headers["x-request-id"]
