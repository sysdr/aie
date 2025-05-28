import os
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy.orm import sessionmaker, declarative_base
import redis.asyncio as redis

# Database URL
DATABASE_URL = os.getenv("DATABASE_URL", "postgresql+asyncpg://quiz_user:quiz_pass@localhost:5432/quiz_db")
REDIS_URL = os.getenv("REDIS_URL", "redis://localhost:6379")

# SQLAlchemy setup
engine = create_async_engine(DATABASE_URL, echo=True)
AsyncSessionLocal = sessionmaker(
    engine, class_=AsyncSession, expire_on_commit=False
)
Base = declarative_base()

# Redis setup
redis_client = redis.from_url(REDIS_URL, decode_responses=True)

# Dependency for getting database session
async def get_db():
    async with AsyncSessionLocal() as session:
        try:
            yield session
        finally:
            await session.close()

async def get_redis():
    return redis_client
