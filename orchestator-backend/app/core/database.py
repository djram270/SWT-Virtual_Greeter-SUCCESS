from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy.orm import sessionmaker, declarative_base
from app.core.config import settings

DATABASE_URL = f"postgresql+asyncpg://{settings.db_user}:{settings.db_pass}@{settings.db_host}:{settings.db_port}/{settings.db_name}"

engine = create_async_engine(DATABASE_URL, echo=True)

Base = declarative_base()

AsyncSessionLocal = sessionmaker(
    bind=engine, class_=AsyncSession, expire_on_commit=False
)

async def get_db():
    async with AsyncSessionLocal() as session:
        yield session


async def init_db():
    """Create database tables from ORM models (call at startup in development)."""
    from importlib import import_module

    try:
        import_module("app.models.entity")
    except Exception:
        pass

    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
