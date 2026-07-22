from types import SimpleNamespace
from typing import Any, ClassVar

import httpx
from openai import APITimeoutError

from app.config import Settings
from app.schemas.analysis import AnalyzeTextRequest, ExtractedFood, MealExtraction
from app.services.meal_analysis import MealAnalysisService


class FakeResponses:
    def __init__(self) -> None:
        self.calls: list[dict[str, Any]] = []

    async def parse(self, **kwargs: Any) -> SimpleNamespace:
        self.calls.append(kwargs)
        if kwargs["model"] == "gpt-5.4-mini":
            raise APITimeoutError(request=httpx.Request("POST", "https://api.openai.com"))
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
