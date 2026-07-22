from fastapi import APIRouter, Request, Response, status

from app.schemas.health import HealthResponse

router = APIRouter(tags=["Service health"])


@router.get("/health", response_model=HealthResponse, summary="Check service readiness")
async def health(request: Request, response: Response) -> HealthResponse:
    database_ready = await request.app.state.database.is_ready()
    if not database_ready:
        response.status_code = status.HTTP_503_SERVICE_UNAVAILABLE
    settings = request.app.state.settings
    return HealthResponse(
        status="ok" if database_ready else "degraded",
        service=settings.app_name,
        version=settings.app_version,
        environment=settings.environment,
        database="ok" if database_ready else "unavailable",
    )
