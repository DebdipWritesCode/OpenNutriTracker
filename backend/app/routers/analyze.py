from typing import Annotated

from fastapi import APIRouter, Depends

from app.routers.dependencies import OpenAIAPIKey, get_meal_analysis_service
from app.schemas.analysis import AnalyzeTextRequest, AnalyzeTextResponse
from app.schemas.error import ErrorResponse
from app.services import MealAnalysisService

router = APIRouter(prefix="/analyze", tags=["AI meal analysis"])


@router.post(
    "/text",
    response_model=AnalyzeTextResponse,
    responses={
        401: {"model": ErrorResponse, "description": "Missing or invalid OpenAI API key"},
        422: {"description": "Invalid meal description"},
        502: {"model": ErrorResponse, "description": "AI provider unavailable"},
    },
    summary="Extract foods and portions from meal text",
)
async def analyze_text(
    payload: AnalyzeTextRequest,
    service: Annotated[MealAnalysisService, Depends(get_meal_analysis_service)],
    openai_api_key: OpenAIAPIKey = None,
) -> AnalyzeTextResponse:
    result = await service.analyze_text(payload, openai_api_key)
    return AnalyzeTextResponse(
        foods=result.extraction.foods,
        notes=result.extraction.notes,
        model_used=result.model_used,
    )
