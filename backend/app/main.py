from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import Settings, get_settings
from app.database import DatabaseManager
from app.routers import analyze_router, health_router
from app.services import MealAnalysisService
from app.services.errors import ServiceError
from app.utils.errors import service_error_handler
from app.utils.logging import configure_logging
from app.utils.request_id import RequestIDMiddleware


def create_app(settings: Settings | None = None) -> FastAPI:
    resolved_settings = settings or get_settings()
    resolved_settings.ensure_sqlite_directory()
    configure_logging(resolved_settings.log_level)
    database = DatabaseManager(resolved_settings.database_url)

    @asynccontextmanager
    async def lifespan(_: FastAPI) -> AsyncIterator[None]:
        await database.initialize()
        yield
        await database.close()

    application = FastAPI(
        title=resolved_settings.app_name,
        version=resolved_settings.app_version,
        description=(
            "Self-hosted AI meal parsing for OpenNutriTracker. AI endpoints identify foods and "
            "portions only; nutrition values must come from the nutrition engine."
        ),
        lifespan=lifespan,
        docs_url="/docs",
        redoc_url="/redoc",
        openapi_url="/openapi.json",
    )
    application.state.settings = resolved_settings
    application.state.database = database
    application.state.meal_analysis_service = MealAnalysisService(resolved_settings)

    application.add_middleware(RequestIDMiddleware)
    application.add_middleware(
        CORSMiddleware,
        allow_origins=resolved_settings.cors_origins,
        allow_credentials=False,
        allow_methods=["GET", "POST", "OPTIONS"],
        allow_headers=["Content-Type", "X-OpenAI-API-Key", "X-Request-ID"],
        expose_headers=["X-Request-ID"],
    )
    application.add_exception_handler(ServiceError, service_error_handler)
    application.include_router(health_router)
    application.include_router(analyze_router, prefix=resolved_settings.api_prefix)

    @application.get("/", include_in_schema=False)
    async def root() -> dict[str, str]:
        return {
            "service": resolved_settings.app_name,
            "health": "/health",
            "docs": "/docs",
        }

    return application


app = create_app()
