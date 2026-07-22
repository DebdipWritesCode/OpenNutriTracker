from typing import Any

from app.config import Settings


def test_cors_origins_accept_comma_separated_direct_value() -> None:
    settings = Settings(cors_origins="https://one.example, https://two.example")

    assert settings.cors_origins == ["https://one.example", "https://two.example"]


def test_empty_openai_key_enables_byok_only_mode() -> None:
    settings = Settings(openai_api_key="")

    assert settings.openai_api_key is None


def test_empty_access_token_is_treated_as_unconfigured() -> None:
    settings = Settings(access_token="")

    assert settings.access_token is None


def test_cors_origins_accept_comma_separated_environment_value(monkeypatch: Any) -> None:
    monkeypatch.setenv(
        "ONT_AI_CORS_ORIGINS",
        "https://one.example, https://two.example",
    )

    settings = Settings(_env_file=None)

    assert settings.cors_origins == ["https://one.example", "https://two.example"]


def test_serverless_runtime_uses_writable_temporary_database(monkeypatch: Any) -> None:
    monkeypatch.delenv("ONT_AI_DATABASE_URL", raising=False)
    monkeypatch.setenv("VERCEL", "1")

    settings = Settings(_env_file=None)

    assert settings.database_url == "sqlite+aiosqlite:////tmp/opennutritracker_ai.db"


def test_explicit_database_url_overrides_serverless_default(monkeypatch: Any) -> None:
    monkeypatch.setenv("VERCEL", "1")
    monkeypatch.setenv("ONT_AI_DATABASE_URL", "sqlite+aiosqlite:////data/ai.db")

    settings = Settings(_env_file=None)

    assert settings.database_url == "sqlite+aiosqlite:////data/ai.db"
