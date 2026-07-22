import os
import tempfile
from functools import lru_cache
from pathlib import Path
from typing import Annotated, Literal

from pydantic import Field, SecretStr, field_validator
from pydantic_settings import BaseSettings, NoDecode, SettingsConfigDict


def _default_database_url() -> str:
    """Use the runtime's writable temp directory on serverless platforms."""
    is_serverless = any(
        os.getenv(variable)
        for variable in ("VERCEL", "AWS_LAMBDA_FUNCTION_NAME", "LAMBDA_TASK_ROOT")
    )
    if is_serverless:
        database_path = Path(tempfile.gettempdir()) / "opennutritracker_ai.db"
        return f"sqlite+aiosqlite:///{database_path.as_posix()}"
    return "sqlite+aiosqlite:///./data/opennutritracker_ai.db"


class Settings(BaseSettings):
    """Environment-backed service configuration.

    The optional server API key is intentionally empty by default. When it is
    empty, AI endpoints require a per-request BYOK key from the Flutter app.
    """

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        env_prefix="ONT_AI_",
        case_sensitive=False,
        extra="ignore",
    )

    app_name: str = "OpenNutriTracker AI"
    app_version: str = "0.1.0"
    environment: Literal["development", "test", "production"] = "development"
    api_prefix: str = "/api/v1"
    log_level: str = "INFO"

    database_url: str = Field(default_factory=_default_database_url)
    cors_origins: Annotated[list[str], NoDecode] = Field(
        default_factory=lambda: ["http://localhost:3000", "http://localhost:8080"]
    )

    openai_api_key: SecretStr | None = None
    openai_primary_model: str = "gpt-5.4-mini"
    openai_fallback_model: str = "gpt-5.4"
    openai_timeout_seconds: float = Field(default=45.0, gt=0, le=120)
    openai_max_output_tokens: int = Field(default=1200, ge=256, le=8000)

    @field_validator("cors_origins", mode="before")
    @classmethod
    def parse_cors_origins(cls, value: object) -> object:
        if isinstance(value, str):
            return [origin.strip() for origin in value.split(",") if origin.strip()]
        return value

    @field_validator("openai_api_key", mode="before")
    @classmethod
    def empty_secret_is_none(cls, value: object) -> object:
        if isinstance(value, str) and not value.strip():
            return None
        return value

    def ensure_sqlite_directory(self) -> None:
        prefix = "sqlite+aiosqlite:///"
        if not self.database_url.startswith(prefix):
            return
        database_path = self.database_url.removeprefix(prefix)
        if database_path == ":memory:":
            return
        Path(database_path).expanduser().resolve().parent.mkdir(parents=True, exist_ok=True)


@lru_cache
def get_settings() -> Settings:
    return Settings()
