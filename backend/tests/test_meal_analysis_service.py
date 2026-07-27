from types import SimpleNamespace
from typing import Any, ClassVar

import httpx
from openai import APITimeoutError

from app.config import Settings
from app.schemas.analysis import (
    ActivityExtraction,
    AnalyzeActivityRequest,
    AnalyzeImageRequest,
    AnalyzeTextRequest,
    ExtractedExercise,
    ExtractedFood,
    MealCorrectionTurn,
    MealExtraction,
    MealRefinement,
    RefineImageRequest,
)
from app.services.meal_analysis import MealAnalysisService


class FakeResponses:
    def __init__(self) -> None:
        self.calls: list[dict[str, Any]] = []

    async def parse(self, **kwargs: Any) -> SimpleNamespace:
        self.calls.append(kwargs)
        if kwargs["model"] == "gpt-5.4-mini":
            raise APITimeoutError(request=httpx.Request("POST", "https://api.openai.com"))
        if kwargs["text_format"] is MealRefinement:
            return SimpleNamespace(
                output_parsed=MealRefinement(
                    foods=[
                        ExtractedFood(
                            original_text="180g paneer curry",
                            canonical_name="paneer curry",
                            quantity=180,
                            unit="g",
                            estimated_grams=180,
                            confidence=0.96,
                        )
                    ],
                    assistant_message="Changed the dish to paneer curry and set it to 180 g.",
                )
            )
        if kwargs["text_format"] is ActivityExtraction:
            return SimpleNamespace(
                output_parsed=ActivityExtraction(
                    exercises=[
                        ExtractedExercise(
                            original_text="3 sets of 8 dumbbell press at 17.5 kg",
                            canonical_name="dumbbell press",
                            sets=3,
                            reps_per_set=8,
                            load_value=17.5,
                            load_unit="kg",
                            confidence=0.98,
                        )
                    ]
                )
            )
        return SimpleNamespace(
            output_parsed=MealExtraction(
                foods=[
                    ExtractedFood(
                        original_text="190g rice",
                        canonical_name="cooked rice",
                        quantity=190,
                        unit="g",
                        estimated_grams=190,
                        confidence=0.99,
                    )
                ]
            )
        )


class FakeOpenAIClient:
    last_api_key: ClassVar[str | None] = None
    last_instance: ClassVar["FakeOpenAIClient | None"] = None

    def __init__(self, *, api_key: str, **_: Any) -> None:
        FakeOpenAIClient.last_api_key = api_key
        FakeOpenAIClient.last_instance = self
        self.responses = FakeResponses()
        self.closed = False

    async def close(self) -> None:
        self.closed = True


async def test_service_uses_byok_and_falls_back_without_storing_prompt(monkeypatch: Any) -> None:
    monkeypatch.setattr("app.services.meal_analysis.AsyncOpenAI", FakeOpenAIClient)
    settings = Settings(
        environment="test",
        openai_api_key="server-key",
        openai_primary_model="gpt-5.4-mini",
        openai_fallback_model="gpt-5.4",
    )
    service = MealAnalysisService(settings)

    result = await service.analyze_text(
        AnalyzeTextRequest(text="190g rice", locale="en-IN"),
        "user-key",
    )

    assert FakeOpenAIClient.last_api_key == "user-key"
    assert result.model_used == "gpt-5.4"
    assert result.extraction.foods[0].estimated_grams == 190

    client = FakeOpenAIClient.last_instance
    assert client is not None
    assert [call["model"] for call in client.responses.calls] == ["gpt-5.4-mini", "gpt-5.4"]
    assert all(call["store"] is False for call in client.responses.calls)
    assert all(call["reasoning"] == {"effort": "none"} for call in client.responses.calls)
    assert client.closed is True


async def test_service_sends_image_as_high_detail_data_url(monkeypatch: Any) -> None:
    monkeypatch.setattr("app.services.meal_analysis.AsyncOpenAI", FakeOpenAIClient)
    settings = Settings(
        environment="test",
        openai_api_key="server-key",
        openai_primary_model="gpt-5.4",
        openai_fallback_model="gpt-5.4",
    )
    service = MealAnalysisService(settings)

    await service.analyze_image(
        AnalyzeImageRequest(
            image_base64="iVBORw0KGgp0ZXN0",
            mime_type="image/png",
            locale="en-IN",
        ),
        None,
    )

    client = FakeOpenAIClient.last_instance
    assert client is not None
    call = client.responses.calls[0]
    content = call["input"][0]["content"]
    assert content[1]["type"] == "input_image"
    assert content[1]["detail"] == "high"
    assert content[1]["image_url"].startswith("data:image/png;base64,")
    assert "Never calculate or return calories" in call["instructions"]
    assert call["store"] is False


async def test_service_parses_activity_without_requesting_energy(monkeypatch: Any) -> None:
    monkeypatch.setattr("app.services.meal_analysis.AsyncOpenAI", FakeOpenAIClient)
    settings = Settings(
        environment="test",
        openai_api_key="server-key",
        openai_primary_model="gpt-5.4",
        openai_fallback_model="gpt-5.4",
    )
    service = MealAnalysisService(settings)

    result = await service.analyze_activity(
        AnalyzeActivityRequest(
            text="3 sets of 8 dumbbell press at 17.5 kg",
            locale="en-IN",
        ),
        None,
    )

    assert result.extraction.exercises[0].load_value == 17.5
    client = FakeOpenAIClient.last_instance
    assert client is not None
    call = client.responses.calls[0]
    assert call["text_format"] is ActivityExtraction
    assert call["store"] is False
    assert "Never calculate or return calories" in call["instructions"]
    assert "Never infer" in call["instructions"]
    assert "duration" in call["instructions"]


async def test_service_refines_with_photo_current_draft_and_history(
    monkeypatch: Any,
) -> None:
    monkeypatch.setattr("app.services.meal_analysis.AsyncOpenAI", FakeOpenAIClient)
    settings = Settings(
        environment="test",
        openai_api_key="server-key",
        openai_primary_model="gpt-5.4",
        openai_fallback_model="gpt-5.4",
    )
    service = MealAnalysisService(settings)

    result = await service.refine_image(
        RefineImageRequest(
            image_base64="iVBORw0KGgp0ZXN0",
            mime_type="image/png",
            locale="en-IN",
            correction="That dish is paneer curry and the portion was 180 g.",
            current_foods=[
                ExtractedFood(
                    original_text="mixed vegetable dish",
                    canonical_name="mixed cooked vegetable dish",
                    quantity=1,
                    unit="bowl",
                    estimated_grams=120,
                    confidence=0.55,
                    requires_user_confirmation=True,
                )
            ],
            correction_history=[
                MealCorrectionTurn(
                    instruction="There was one bowl.",
                    assistant_message="Kept one bowl in the meal draft.",
                )
            ],
        ),
        None,
    )

    assert result.refinement.foods[0].canonical_name == "paneer curry"
    assert result.refinement.assistant_message.startswith("Changed the dish")
    client = FakeOpenAIClient.last_instance
    assert client is not None
    call = client.responses.calls[0]
    prompt_data = call["input"][0]["content"][0]["text"]
    assert '"latest_correction": "That dish is paneer curry' in prompt_data
    assert '"current_foods"' in prompt_data
    assert '"correction_history"' in prompt_data
    assert call["input"][0]["content"][1]["detail"] == "high"
    assert call["text_format"] is MealRefinement
    assert call["store"] is False
    assert "Never calculate or return calories" in call["instructions"]
