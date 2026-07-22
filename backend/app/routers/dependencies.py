from typing import Annotated

from fastapi import Header, Request

from app.services import MealAnalysisService


def get_meal_analysis_service(request: Request) -> MealAnalysisService:
    return request.app.state.meal_analysis_service


OpenAIAPIKey = Annotated[
    str | None,
    Header(
        alias="X-OpenAI-API-Key",
        description="Optional per-request OpenAI key. It is used in memory and is never persisted.",
        include_in_schema=True,
    ),
]
