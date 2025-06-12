import asyncpg
import redis.asyncio as redis
import os
from typing import Optional
import json

class DatabaseService:
    def __init__(self):
        self.pg_pool = None
        self.redis_client = None
    
    async def init_db(self):
        # Initialize PostgreSQL connection pool
        self.pg_pool = await asyncpg.create_pool(
            os.getenv('DATABASE_URL', 'postgresql://postgres:password@localhost:5432/quiz_db'),
            min_size=5,
            max_size=20
        )
        
        # Initialize Redis client
        self.redis_client = redis.from_url(
            os.getenv('REDIS_URL', 'redis://localhost:6379'),
            decode_responses=True
        )
        
        # Create tables if they don't exist
        await self.create_tables()
    
    async def create_tables(self):
        async with self.pg_pool.acquire() as conn:
            await conn.execute('''
                CREATE TABLE IF NOT EXISTS quiz_attempts (
                    id VARCHAR(36) PRIMARY KEY,
                    user_id VARCHAR(36) NOT NULL,
                    quiz_id VARCHAR(36) NOT NULL,
                    started_at TIMESTAMP DEFAULT NOW(),
                    current_question INTEGER DEFAULT 0,
                    answers JSONB DEFAULT '{}',
                    status VARCHAR(20) DEFAULT 'started',
                    time_remaining INTEGER DEFAULT 1800,
                    last_updated TIMESTAMP DEFAULT NOW(),
                    version INTEGER DEFAULT 1,
                    created_at TIMESTAMP DEFAULT NOW(),
                    updated_at TIMESTAMP DEFAULT NOW()
                );
                
                CREATE INDEX IF NOT EXISTS idx_user_attempts ON quiz_attempts(user_id);
                CREATE INDEX IF NOT EXISTS idx_quiz_attempts ON quiz_attempts(quiz_id);
                CREATE INDEX IF NOT EXISTS idx_status_attempts ON quiz_attempts(status);
            ''')

db_service = DatabaseService()

async def init_db():
    await db_service.init_db()

async def get_db():
    return db_service
