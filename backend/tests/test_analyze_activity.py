from httpx import AsyncClient

from app.schemas.analysis import (
    ActivityExtraction,
    AnalyzeActivityRequest,
    ExtractedExercise,
)
from app.services import ActivityAnalysisResult


class FakeActivityAnalysisService:
    async def analyze_activity(
        self,
        request: AnalyzeActivityRequest,
        request_api_key: str | None,
    ) -> ActivityAnalysisResult:
        assert request.locale == "en-IN"
        assert request_api_key == "sk-test-not-real"
        return ActivityAnalysisResult(
            extraction=ActivityExtraction(
                exercises=[
                    ExtractedExercise(
                        original_text="dumbbell press 17.5 kg for 3 sets of 8",
                        canonical_name="dumbbell press",
                        sets=3,
                        reps_per_set=8,
                        load_value=17.5,
                        load_unit="kg",
                        confidence=0.98,
                    ),
                    ExtractedExercise(
                        original_text="shoulder press 3 sets 8 reps with 15 kg",
                        canonical_name="shoulder press",
                        sets=3,
                        reps_per_set=8,
                        load_value=15,
                        load_unit="kg",
                        confidence=0.97,
                    ),
                ],
                notes=[],
            ),
            model_used="gpt-5.4-mini",
        )


async def test_analyze_activity_returns_structure_without_energy(client: AsyncClient) -> None:
    client._transport.app.state.meal_analysis_service = (  # type: ignore[attr-defined]
        FakeActivityAnalysisService()
    )

    response = await client.post(
        "/api/v1/analyze/activity",
        headers={"X-OpenAI-API-Key": "sk-test-not-real"},
        json={
            "text": (
                "Dumbbell press 17.5 kg for 3 sets of 8 and shoulder press 3 sets of 8 with 15 kg"
            ),
            "locale": "en-IN",
        },
    )

    assert response.status_code == 200
    body = response.json()
    assert body["model_used"] == "gpt-5.4-mini"
    assert body["exercises"][0]["sets"] == 3
    assert body["exercises"][0]["load_value"] == 17.5
    assert body["exercises"][1]["canonical_name"] == "shoulder press"
    assert "calories" not in body
    assert "mets" not in body


async def test_analyze_activity_rejects_empty_input(client: AsyncClient) -> None:
    response = await client.post("/api/v1/analyze/activity", json={"text": " "})

    assert response.status_code == 422
