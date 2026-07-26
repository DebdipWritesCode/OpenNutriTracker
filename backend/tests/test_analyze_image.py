import base64

from httpx import AsyncClient

from app.schemas.analysis import (
    AnalyzeImageRequest,
    ExtractedFood,
    MealExtraction,
    MealRefinement,
    RefineImageRequest,
)
from app.services import MealAnalysisResult, MealRefinementResult


class FakeMealImageAnalysisService:
    def __init__(self) -> None:
        self.received_key: str | None = None
        self.received_payload: AnalyzeImageRequest | None = None

    async def analyze_image(
        self,
        request: AnalyzeImageRequest,
        request_api_key: str | None,
    ) -> MealAnalysisResult:
        self.received_key = request_api_key
        self.received_payload = request
        return MealAnalysisResult(
            extraction=MealExtraction(
                foods=[
                    ExtractedFood(
                        original_text="bowl of poha",
                        canonical_name="poha",
                        quantity=1,
                        unit="bowl",
                        estimated_grams=180,
                        confidence=0.78,
                        requires_user_confirmation=True,
                    )
                ],
                notes=["Confirm the bowl size."],
            ),
            model_used="gpt-5.4-mini",
        )

    async def refine_image(
        self,
        request: RefineImageRequest,
        request_api_key: str | None,
    ) -> MealRefinementResult:
        self.received_key = request_api_key
        self.received_payload = request
        return MealRefinementResult(
            refinement=MealRefinement(
                foods=[
                    ExtractedFood(
                        original_text="paneer curry",
                        canonical_name="paneer curry",
                        quantity=180,
                        unit="g",
                        estimated_grams=180,
                        confidence=0.96,
                        requires_user_confirmation=False,
                    )
                ],
                notes=[],
                assistant_message=(
                    "Changed the mixed vegetable dish to paneer curry and set it to 180 g."
                ),
            ),
            model_used="gpt-5.4-mini",
        )


def _jpeg_payload() -> str:
    return base64.b64encode(b"\xff\xd8\xff\xe0test-meal-photo").decode()


async def test_analyze_image_returns_editable_foods(client: AsyncClient) -> None:
    service = FakeMealImageAnalysisService()
    client._transport.app.state.meal_analysis_service = service  # type: ignore[attr-defined]

    response = await client.post(
        "/api/v1/analyze/image",
        headers={"X-OpenAI-API-Key": "sk-test-not-real"},
        json={
            "image_base64": _jpeg_payload(),
            "mime_type": "image/jpeg",
            "locale": "en-IN",
        },
    )

    assert response.status_code == 200
    assert service.received_key == "sk-test-not-real"
    assert service.received_payload is not None
    assert service.received_payload.locale == "en-IN"
    assert response.json()["foods"][0]["canonical_name"] == "poha"
    assert response.json()["foods"][0]["estimated_grams"] == 180
    assert "calories" not in response.json()["foods"][0]


async def test_analyze_image_rejects_invalid_base64(client: AsyncClient) -> None:
    response = await client.post(
        "/api/v1/analyze/image",
        json={
            "image_base64": "not-base64!",
            "mime_type": "image/jpeg",
            "locale": "en",
        },
    )

    assert response.status_code == 422


async def test_analyze_image_rejects_mismatched_mime_type(client: AsyncClient) -> None:
    response = await client.post(
        "/api/v1/analyze/image",
        json={
            "image_base64": _jpeg_payload(),
            "mime_type": "image/png",
            "locale": "en",
        },
    )

    assert response.status_code == 422


async def test_refine_image_returns_complete_corrected_draft(client: AsyncClient) -> None:
    service = FakeMealImageAnalysisService()
    client._transport.app.state.meal_analysis_service = service  # type: ignore[attr-defined]

    response = await client.post(
        "/api/v1/analyze/image/refine",
        headers={"X-OpenAI-API-Key": "sk-test-not-real"},
        json={
            "image_base64": _jpeg_payload(),
            "mime_type": "image/jpeg",
            "locale": "en-IN",
            "correction": "That is paneer curry, not mixed vegetables, and it was 180 g.",
            "current_foods": [
                {
                    "original_text": "mixed vegetable dish",
                    "canonical_name": "mixed cooked vegetable dish",
                    "quantity": 1,
                    "unit": "bowl",
                    "estimated_grams": 120,
                    "preparation": None,
                    "confidence": 0.55,
                    "requires_user_confirmation": True,
                }
            ],
            "correction_history": [
                {
                    "instruction": "There was only one bowl.",
                    "assistant_message": "Kept one bowl and updated its portion estimate.",
                }
            ],
        },
    )

    assert response.status_code == 200
    assert service.received_key == "sk-test-not-real"
    assert isinstance(service.received_payload, RefineImageRequest)
    assert service.received_payload.correction_history[0].instruction == (
        "There was only one bowl."
    )
    assert response.json()["foods"][0]["canonical_name"] == "paneer curry"
    assert response.json()["foods"][0]["estimated_grams"] == 180
    assert "paneer curry" in response.json()["assistant_message"]
    assert "calories" not in response.json()


async def test_refine_image_rejects_an_empty_correction(client: AsyncClient) -> None:
    response = await client.post(
        "/api/v1/analyze/image/refine",
        json={
            "image_base64": _jpeg_payload(),
            "mime_type": "image/jpeg",
            "locale": "en",
            "correction": " ",
            "current_foods": [
                {
                    "original_text": "rice",
                    "canonical_name": "rice",
                    "quantity": 100,
                    "unit": "g",
                    "estimated_grams": 100,
                    "preparation": None,
                    "confidence": 0.9,
                    "requires_user_confirmation": False,
                }
            ],
        },
    )

    assert response.status_code == 422
