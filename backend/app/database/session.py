"""
SQLAlchemy async database session management.
"""

from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker
from sqlalchemy.orm import DeclarativeBase
from app.core.config import settings

# Create async engine (SQLite doesn't support pool_size/max_overflow)
_is_sqlite = settings.DATABASE_URL.startswith("sqlite")
_engine_kwargs = {} if _is_sqlite else {"pool_size": 10, "max_overflow": 20}

engine = create_async_engine(
    settings.DATABASE_URL,
    echo=settings.DEBUG,
    pool_pre_ping=True,
    **_engine_kwargs,
)

# Session factory
AsyncSessionLocal = async_sessionmaker(
    bind=engine,
    class_=AsyncSession,
    expire_on_commit=False,
    autocommit=False,
    autoflush=False,
)


class Base(DeclarativeBase):
    """Base class for all SQLAlchemy models."""
    pass


async def create_db_tables():
    """Create all database tables on application startup."""
    # Import models here to ensure they are registered with Base
    from app.database import models  # noqa: F401
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)


async def get_db() -> AsyncSession:
    """
    Dependency injection for database session.
    Use as a FastAPI dependency: db: AsyncSession = Depends(get_db)
    """
    async with AsyncSessionLocal() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
        finally:
            await session.close()
