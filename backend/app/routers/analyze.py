from typing import Annotated

from fastapi import APIRouter, Depends

from app.routers.dependencies import OpenAIAPIKey, get_meal_analysis_service
from app.schemas.analysis import (
    AnalyzeActivityRequest,
    AnalyzeActivityResponse,
    AnalyzeImageRequest,
    AnalyzeTextRequest,
    AnalyzeTextResponse,
    RefineImageRequest,
    RefineImageResponse,
)
from app.schemas.error import ErrorResponse
from app.security import authorize_ai_request
from app.services import MealAnalysisService

router = APIRouter(prefix="/analyze", tags=["AI analysis"])


@router.post(
    "/activity",
    response_model=AnalyzeActivityResponse,
    responses={
        401: {"model": ErrorResponse, "description": "Missing or invalid access/API key"},
        429: {"model": ErrorResponse, "description": "AI request rate limit exceeded"},
        503: {"model": ErrorResponse, "description": "Production authentication not configured"},
        422: {"description": "Invalid workout description"},
        502: {"model": ErrorResponse, "description": "AI provider unavailable"},
    },
    summary="Extract strength exercises, sets, reps, and loads from text",
)
async def analyze_activity(
    payload: AnalyzeActivityRequest,
    _: Annotated[None, Depends(authorize_ai_request)],
    service: Annotated[MealAnalysisService, Depends(get_meal_analysis_service)],
    openai_api_key: OpenAIAPIKey = None,
) -> AnalyzeActivityResponse:
    result = await service.analyze_activity(payload, openai_api_key)
    return AnalyzeActivityResponse(
        exercises=result.extraction.exercises,
        stated_duration_minutes=result.extraction.stated_duration_minutes,
        notes=result.extraction.notes,
        model_used=result.model_used,
    )


@router.post(
    "/text",
    response_model=AnalyzeTextResponse,
    responses={
        401: {"model": ErrorResponse, "description": "Missing or invalid access/API key"},
        429: {"model": ErrorResponse, "description": "AI request rate limit exceeded"},
        503: {"model": ErrorResponse, "description": "Production authentication not configured"},
        422: {"description": "Invalid meal description"},
        502: {"model": ErrorResponse, "description": "AI provider unavailable"},
    },
    summary="Extract foods and portions from meal text",
)
async def analyze_text(
    payload: AnalyzeTextRequest,
    _: Annotated[None, Depends(authorize_ai_request)],
    service: Annotated[MealAnalysisService, Depends(get_meal_analysis_service)],
    openai_api_key: OpenAIAPIKey = None,
) -> AnalyzeTextResponse:
    result = await service.analyze_text(payload, openai_api_key)
    return AnalyzeTextResponse(
        foods=result.extraction.foods,
        notes=result.extraction.notes,
        model_used=result.model_used,
    )


@router.post(
    "/image",
    response_model=AnalyzeTextResponse,
    responses={
        401: {"model": ErrorResponse, "description": "Missing or invalid access/API key"},
        429: {"model": ErrorResponse, "description": "AI request rate limit exceeded"},
        503: {"model": ErrorResponse, "description": "Production authentication not configured"},
        422: {"description": "Invalid meal photo"},
        502: {"model": ErrorResponse, "description": "AI provider unavailable"},
    },
    summary="Extract foods and portions from a meal photo",
)
async def analyze_image(
    payload: AnalyzeImageRequest,
    _: Annotated[None, Depends(authorize_ai_request)],
    service: Annotated[MealAnalysisService, Depends(get_meal_analysis_service)],
    openai_api_key: OpenAIAPIKey = None,
) -> AnalyzeTextResponse:
    result = await service.analyze_image(payload, openai_api_key)
    return AnalyzeTextResponse(
        foods=result.extraction.foods,
        notes=result.extraction.notes,
        model_used=result.model_used,
    )


@router.post(
    "/image/refine",
    response_model=RefineImageResponse,
    responses={
        401: {"model": ErrorResponse, "description": "Missing or invalid access/API key"},
        429: {"model": ErrorResponse, "description": "AI request rate limit exceeded"},
        503: {"model": ErrorResponse, "description": "Production authentication not configured"},
        422: {"description": "Invalid photo, meal draft, or correction"},
        502: {"model": ErrorResponse, "description": "AI provider unavailable"},
    },
    summary="Correct foods and portions using the original meal photo",
)
async def refine_image(
    payload: RefineImageRequest,
    _: Annotated[None, Depends(authorize_ai_request)],
    service: Annotated[MealAnalysisService, Depends(get_meal_analysis_service)],
    openai_api_key: OpenAIAPIKey = None,
) -> RefineImageResponse:
    result = await service.refine_image(payload, openai_api_key)
    return RefineImageResponse(
        foods=result.refinement.foods,
        notes=result.refinement.notes,
        assistant_message=result.refinement.assistant_message,
        model_used=result.model_used,
    )
