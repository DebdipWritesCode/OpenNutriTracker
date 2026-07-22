from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncEngine, async_sessionmaker, create_async_engine

from app.database.base import Base


class DatabaseManager:
    def __init__(self, database_url: str) -> None:
        self.engine: AsyncEngine = create_async_engine(database_url, pool_pre_ping=True)
        self.session_factory = async_sessionmaker(self.engine, expire_on_commit=False)

    async def initialize(self) -> None:
        # Import model modules before create_all when persistent models are added.
        async with self.engine.begin() as connection:
            await connection.run_sync(Base.metadata.create_all)

    async def is_ready(self) -> bool:
        try:
            async with self.engine.connect() as connection:
                await connection.execute(text("SELECT 1"))
            return True
        except Exception:
            return False

    async def close(self) -> None:
        await self.engine.dispose()
