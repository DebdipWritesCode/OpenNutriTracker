from typing import Any

from app.config import Settings


def test_cors_origins_accept_comma_separated_direct_value() -> None:
    settings = Settings(cors_origins="https://one.example, https://two.example")

    assert settings.cors_origins == ["https://one.example", "https://two.example"]


def test_empty_openai_key_enables_byok_only_mode() -> None:
    settings = Settings(openai_api_key="")

    assert settings.openai_api_key is None


def test_cors_origins_accept_comma_separated_environment_value(monkeypatch: Any) -> None:
    monkeypatch.setenv(
        "ONT_AI_CORS_ORIGINS",
        "https://one.example, https://two.example",
    )

    settings = Settings(_env_file=None)

    assert settings.cors_origins == ["https://one.example", "https://two.example"]
