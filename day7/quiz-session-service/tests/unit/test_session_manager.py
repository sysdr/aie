import pytest
import asyncio
from unittest.mock import AsyncMock, patch, MagicMock
from datetime import datetime
from src.models.attempt import QuizAttempt, AttemptStatus
from src.services.session_manager import session_manager

class SimpleAsyncContextManager:
    def __init__(self, value):
        self.value = value
    async def __aenter__(self):
        return self.value
    async def __aexit__(self, exc_type, exc, tb):
        pass

@pytest.fixture
def session_manager_fixture():
    return session_manager

@pytest.mark.asyncio
async def test_create_session(session_manager_fixture):
    mock_db = AsyncMock()
    mock_conn = AsyncMock()
    mock_conn.execute = AsyncMock()
    mock_pg_pool = MagicMock()
    mock_pg_pool.acquire = lambda: SimpleAsyncContextManager(mock_conn)
    mock_db.pg_pool = mock_pg_pool
    mock_db.redis_client.setex = AsyncMock()
    
    async def mock_get_db():
        return mock_db
    
    with patch('src.services.session_manager.get_db', mock_get_db):
        attempt = await session_manager_fixture.create_session("user123", "quiz456")
        assert attempt.user_id == "user123"
        assert attempt.quiz_id == "quiz456"
        assert attempt.status == AttemptStatus.STARTED
        assert len(attempt.id) > 0

@pytest.mark.asyncio
async def test_update_progress_success(session_manager_fixture):
    mock_db = AsyncMock()
    mock_conn = AsyncMock()
    mock_conn.fetchrow = AsyncMock(return_value={'version': 1, 'answers': '{}'})
    mock_conn.execute = AsyncMock(return_value="UPDATE 1")
    mock_conn.transaction = lambda: SimpleAsyncContextManager(mock_conn)
    mock_pg_pool = MagicMock()
    mock_pg_pool.acquire = lambda: SimpleAsyncContextManager(mock_conn)
    mock_db.pg_pool = mock_pg_pool
    mock_db.redis_client.setex = AsyncMock()
    
    async def mock_get_db():
        return mock_db
    
    with patch('src.services.session_manager.get_db', mock_get_db):
        with patch.object(session_manager_fixture, 'get_session') as mock_get:
            mock_attempt = QuizAttempt(
                id="session123",
                user_id="user123",
                quiz_id="quiz456",
                started_at=datetime.utcnow()
            )
            mock_get.return_value = mock_attempt
            result = await session_manager_fixture.update_progress("session123", 1, "A")
            assert result == True

@pytest.mark.asyncio
async def test_update_progress_version_conflict(session_manager_fixture):
    mock_db = AsyncMock()
    mock_conn = AsyncMock()
    mock_conn.fetchrow = AsyncMock(return_value={'version': 1, 'answers': '{}'})
    mock_conn.execute = AsyncMock(return_value="UPDATE 0")  # Version conflict
    mock_conn.transaction = lambda: SimpleAsyncContextManager(mock_conn)
    mock_pg_pool = MagicMock()
    mock_pg_pool.acquire = lambda: SimpleAsyncContextManager(mock_conn)
    mock_db.pg_pool = mock_pg_pool
    
    async def mock_get_db():
        return mock_db
    
    with patch('src.services.session_manager.get_db', mock_get_db):
        result = await session_manager_fixture.update_progress("session123", 1, "A")
        assert result == False
