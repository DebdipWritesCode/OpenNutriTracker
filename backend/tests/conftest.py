from collections.abc import AsyncIterator
from pathlib import Path

import pytest
from httpx import ASGITransport, AsyncClient

from app.config import Settings
from app.main import create_app


@pytest.fixture
def settings(tmp_path: Path) -> Settings:
    return Settings(
        environment="test",
        database_url=f"sqlite+aiosqlite:///{tmp_path / 'test.db'}",
        cors_origins=["http://localhost:3000"],
        openai_api_key=None,
    )


@pytest.fixture
async def client(settings: Settings) -> AsyncIterator[AsyncClient]:
    app = create_app(settings)
    async with app.router.lifespan_context(app):
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
            yield client
