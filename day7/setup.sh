#!/bin/bash

# Day 7: Quiz Session Management - Complete Implementation Script
# This script creates a fully functional quiz session management service

set -e  # Exit on any error

echo "🚀 Starting Quiz Session Management Implementation..."

# Find Python 3.11 or fallback versions
PYTHON_CMD=$(which python3.11 || which python3.10 || which python3.9 || which python3.8)
if [ -z "$PYTHON_CMD" ]; then
    echo "❌ Error: Could not find Python 3.11, 3.10, 3.9, or 3.8. Please install one of these versions."
    exit 1
fi

echo "🐍 Using Python: $($PYTHON_CMD --version)"

# Create project structure
mkdir -p quiz-session-service/{src/{models,services,api,storage,utils},tests/{unit,integration},docker,scripts,config}
cd quiz-session-service

echo "📁 Created project directory structure"

# Create requirements.txt
cat > requirements.txt << 'EOF'
fastapi==0.110.0
uvicorn==0.29.0
redis==5.0.4
sqlalchemy==2.0.29
asyncpg==0.29.0
pydantic==2.6.4
python-jose[cryptography]==3.3.0
pytest==8.1.1
pytest-asyncio==0.23.6
httpx==0.27.0
python-multipart==0.0.9
alembic==1.13.1
python-dotenv==1.0.1
EOF

# Create environment configuration
cat > config/.env << 'EOF'
DATABASE_URL=postgresql://postgres:password@localhost:5432/quiz_db
REDIS_URL=redis://localhost:6379
SECRET_KEY=your-secret-key-change-in-production
SESSION_TIMEOUT_MINUTES=30
AUTO_SAVE_INTERVAL_SECONDS=30
EOF

# Create main application file
cat > src/main.py << 'EOF'
from fastapi import FastAPI, Depends, HTTPException
from fastapi.middleware.cors import CORSMiddleware
import uvicorn
from src.api.session_endpoints import router as session_router
from src.services.database import init_db
import asyncio

app = FastAPI(
    title="Quiz Session Management Service",
    version="1.0.0",
    description="Stateful session management for distributed quiz platform"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(session_router, prefix="/api/v1/sessions", tags=["sessions"])

@app.on_event("startup")
async def startup_event():
    await init_db()

@app.get("/health")
async def health_check():
    return {"status": "healthy", "service": "quiz-session-management"}

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8002)
EOF

# Create data models
cat > src/models/attempt.py << 'EOF'
from dataclasses import dataclass, field
from datetime import datetime
from enum import Enum
from typing import Dict, Optional
import json

class AttemptStatus(Enum):
    STARTED = "started"
    IN_PROGRESS = "in_progress"
    COMPLETED = "completed"
    EXPIRED = "expired"
    ABANDONED = "abandoned"

@dataclass
class QuizAttempt:
    id: str
    user_id: str
    quiz_id: str
    started_at: datetime
    current_question: int = 0
    answers: Dict[int, str] = field(default_factory=dict)
    status: AttemptStatus = AttemptStatus.STARTED
    time_remaining: int = 1800  # 30 minutes in seconds
    last_updated: datetime = field(default_factory=datetime.utcnow)
    version: int = 1
    
    def to_dict(self) -> dict:
        return {
            'id': self.id,
            'user_id': self.user_id,
            'quiz_id': self.quiz_id,
            'started_at': self.started_at.isoformat(),
            'current_question': self.current_question,
            'answers': json.dumps(self.answers),
            'status': self.status.value,
            'time_remaining': self.time_remaining,
            'last_updated': self.last_updated.isoformat(),
            'version': self.version
        }
    
    @classmethod
    def from_dict(cls, data: dict) -> 'QuizAttempt':
        return cls(
            id=data['id'],
            user_id=data['user_id'],
            quiz_id=data['quiz_id'],
            started_at=datetime.fromisoformat(data['started_at']),
            current_question=data.get('current_question', 0),
            answers=json.loads(data.get('answers', '{}')),
            status=AttemptStatus(data.get('status', 'started')),
            time_remaining=data.get('time_remaining', 1800),
            last_updated=datetime.fromisoformat(data['last_updated']),
            version=data.get('version', 1)
        )
EOF

# Create database service
cat > src/services/database.py << 'EOF'
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
EOF

# Create session manager service
cat > src/services/session_manager.py << 'EOF'
from src.models.attempt import QuizAttempt, AttemptStatus
from src.services.database import get_db
import uuid
from datetime import datetime, timedelta
from typing import Optional, List
import asyncio
import json
import logging

logger = logging.getLogger(__name__)

class SessionManager:
    def __init__(self):
        self.auto_save_tasks = {}
    
    async def create_session(self, user_id: str, quiz_id: str) -> QuizAttempt:
        """Create a new quiz attempt session"""
        attempt = QuizAttempt(
            id=str(uuid.uuid4()),
            user_id=user_id,
            quiz_id=quiz_id,
            started_at=datetime.utcnow()
        )
        
        db = await get_db()
        
        # Store in PostgreSQL for persistence
        async with db.pg_pool.acquire() as conn:
            await conn.execute('''
                INSERT INTO quiz_attempts 
                (id, user_id, quiz_id, started_at, current_question, answers, status, time_remaining, version)
                VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
            ''', attempt.id, attempt.user_id, attempt.quiz_id, attempt.started_at,
                attempt.current_question, json.dumps(attempt.answers), 
                attempt.status.value, attempt.time_remaining, attempt.version)
        
        # Cache in Redis for fast access
        await db.redis_client.setex(
            f"session:{attempt.id}",
            1800,  # 30 minutes TTL
            json.dumps(attempt.to_dict())
        )
        
        # Start auto-save task
        self.auto_save_tasks[attempt.id] = asyncio.create_task(
            self._auto_save_loop(attempt.id)
        )
        
        logger.info(f"Created session {attempt.id} for user {user_id}")
        return attempt
    
    async def get_session(self, session_id: str) -> Optional[QuizAttempt]:
        """Retrieve session from cache or database"""
        db = await get_db()
        
        # Try Redis first
        cached_data = await db.redis_client.get(f"session:{session_id}")
        if cached_data:
            return QuizAttempt.from_dict(json.loads(cached_data))
        
        # Fallback to PostgreSQL
        async with db.pg_pool.acquire() as conn:
            row = await conn.fetchrow(
                'SELECT * FROM quiz_attempts WHERE id = $1', session_id
            )
            if row:
                attempt_dict = dict(row)
                attempt_dict['answers'] = json.loads(attempt_dict['answers'])
                return QuizAttempt.from_dict(attempt_dict)
        
        return None
    
    async def update_progress(self, session_id: str, question_id: int, answer: str) -> bool:
        """Update quiz progress with optimistic locking"""
        db = await get_db()
        
        async with db.pg_pool.acquire() as conn:
            async with conn.transaction():
                # Get current version
                current = await conn.fetchrow(
                    'SELECT version, answers FROM quiz_attempts WHERE id = $1',
                    session_id
                )
                
                if not current:
                    return False
                
                # Update answers
                answers = json.loads(current['answers'])
                answers[str(question_id)] = answer
                new_version = current['version'] + 1
                
                # Atomic update with version check
                result = await conn.execute('''
                    UPDATE quiz_attempts 
                    SET answers = $1, current_question = $2, last_updated = NOW(), version = $4
                    WHERE id = $3 AND version = $5
                ''', json.dumps(answers), question_id, session_id, new_version, current['version'])
                
                if result == "UPDATE 0":
                    # Optimistic lock failed
                    logger.warning(f"Version conflict for session {session_id}")
                    return False
                
                # Update Redis cache
                attempt = await self.get_session(session_id)
                if attempt:
                    attempt.answers[question_id] = answer
                    attempt.current_question = question_id
                    attempt.version = new_version
                    await db.redis_client.setex(
                        f"session:{session_id}",
                        1800,
                        json.dumps(attempt.to_dict())
                    )
                
                return True
    
    async def complete_session(self, session_id: str) -> bool:
        """Complete a quiz session"""
        db = await get_db()
        
        async with db.pg_pool.acquire() as conn:
            result = await conn.execute('''
                UPDATE quiz_attempts 
                SET status = $1, last_updated = NOW()
                WHERE id = $2 AND status != 'completed'
            ''', AttemptStatus.COMPLETED.value, session_id)
            
            if result != "UPDATE 0":
                await db.redis_client.delete(f"session:{session_id}")
                
                # Cancel auto-save task
                if session_id in self.auto_save_tasks:
                    self.auto_save_tasks[session_id].cancel()
                    del self.auto_save_tasks[session_id]
                
                logger.info(f"Completed session {session_id}")
                return True
        
        return False
    
    async def _auto_save_loop(self, session_id: str):
        """Background auto-save every 30 seconds"""
        try:
            while True:
                await asyncio.sleep(30)
                
                attempt = await self.get_session(session_id)
                if not attempt or attempt.status == AttemptStatus.COMPLETED:
                    break
                
                # Update last_updated timestamp
                db = await get_db()
                async with db.pg_pool.acquire() as conn:
                    await conn.execute(
                        'UPDATE quiz_attempts SET last_updated = NOW() WHERE id = $1',
                        session_id
                    )
                
                logger.debug(f"Auto-saved session {session_id}")
                
        except asyncio.CancelledError:
            logger.info(f"Auto-save cancelled for session {session_id}")
        except Exception as e:
            logger.error(f"Auto-save error for session {session_id}: {e}")

session_manager = SessionManager()
EOF

# Create API endpoints
cat > src/api/session_endpoints.py << 'EOF'
from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel
from src.services.session_manager import session_manager
from typing import Dict, Optional
import logging

logger = logging.getLogger(__name__)

router = APIRouter()

class CreateSessionRequest(BaseModel):
    user_id: str
    quiz_id: str

class UpdateProgressRequest(BaseModel):
    question_id: int
    answer: str

class SessionResponse(BaseModel):
    id: str
    user_id: str
    quiz_id: str
    current_question: int
    status: str
    time_remaining: int
    answers: Dict[int, str]

@router.post("/", response_model=SessionResponse)
async def create_session(request: CreateSessionRequest):
    """Create a new quiz session"""
    try:
        attempt = await session_manager.create_session(
            request.user_id, 
            request.quiz_id
        )
        
        return SessionResponse(
            id=attempt.id,
            user_id=attempt.user_id,
            quiz_id=attempt.quiz_id,
            current_question=attempt.current_question,
            status=attempt.status.value,
            time_remaining=attempt.time_remaining,
            answers=attempt.answers
        )
    except Exception as e:
        logger.error(f"Failed to create session: {e}")
        raise HTTPException(status_code=500, detail="Failed to create session")

@router.get("/{session_id}", response_model=SessionResponse)
async def get_session(session_id: str):
    """Get session details"""
    attempt = await session_manager.get_session(session_id)
    
    if not attempt:
        raise HTTPException(status_code=404, detail="Session not found")
    
    return SessionResponse(
        id=attempt.id,
        user_id=attempt.user_id,
        quiz_id=attempt.quiz_id,
        current_question=attempt.current_question,
        status=attempt.status.value,
        time_remaining=attempt.time_remaining,
        answers=attempt.answers
    )

@router.put("/{session_id}/progress")
async def update_progress(session_id: str, request: UpdateProgressRequest):
    """Update quiz progress"""
    success = await session_manager.update_progress(
        session_id,
        request.question_id,
        request.answer
    )
    
    if not success:
        raise HTTPException(
            status_code=409, 
            detail="Update conflict - session may have been modified"
        )
    
    return {"message": "Progress updated successfully"}

@router.post("/{session_id}/complete")
async def complete_session(session_id: str):
    """Complete a quiz session"""
    success = await session_manager.complete_session(session_id)
    
    if not success:
        raise HTTPException(
            status_code=404, 
            detail="Session not found or already completed"
        )
    
    return {"message": "Session completed successfully"}

@router.get("/user/{user_id}")
async def get_user_sessions(user_id: str):
    """Get all sessions for a user"""
    from services.database import get_db
    
    db = await get_db()
    async with db.pg_pool.acquire() as conn:
        rows = await conn.fetch(
            'SELECT * FROM quiz_attempts WHERE user_id = $1 ORDER BY created_at DESC',
            user_id
        )
        
        sessions = []
        for row in rows:
            attempt_dict = dict(row)
            attempt_dict['answers'] = attempt_dict['answers'] or {}
            sessions.append({
                'id': attempt_dict['id'],
                'quiz_id': attempt_dict['quiz_id'],
                'status': attempt_dict['status'],
                'started_at': attempt_dict['started_at'].isoformat(),
                'current_question': attempt_dict['current_question']
            })
        
        return {"sessions": sessions}
EOF

# Create Docker configuration
cat > docker/Dockerfile << 'EOF'
FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY src/ ./src/
COPY config/ ./config/

EXPOSE 8002

CMD ["python", "-m", "src.main"]
EOF

cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  app:
    build:
      context: .
      dockerfile: docker/Dockerfile
    ports:
      - "8002:8002"
    environment:
      - DATABASE_URL=postgresql://postgres:password@postgres:5432/quiz_db
      - REDIS_URL=redis://redis:6379
    depends_on:
      - postgres
      - redis
    volumes:
      - .:/app

  postgres:
    image: postgres:15
    environment:
      POSTGRES_DB: quiz_db
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: password
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data

volumes:
  postgres_data:
  redis_data:
EOF

# Create unit tests
cat > tests/unit/test_session_manager.py << 'EOF'
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
EOF

# Create integration tests
cat > tests/integration/test_api.py << 'EOF'
import pytest
import httpx
import asyncio
from fastapi.testclient import TestClient
import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '../../src'))
from main import app

@pytest.fixture
def client():
    return TestClient(app)

def test_health_check(client):
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json()["status"] == "healthy"

@pytest.mark.asyncio
async def test_session_lifecycle():
    async with httpx.AsyncClient(app=app, base_url="http://test") as client:
        # Create session
        create_response = await client.post(
            "/api/v1/sessions/",
            json={"user_id": "test_user", "quiz_id": "test_quiz"}
        )
        assert create_response.status_code == 200
        session_data = create_response.json()
        session_id = session_data["id"]
        
        # Get session
        get_response = await client.get(f"/api/v1/sessions/{session_id}")
        assert get_response.status_code == 200
        
        # Update progress
        progress_response = await client.put(
            f"/api/v1/sessions/{session_id}/progress",
            json={"question_id": 1, "answer": "A"}
        )
        assert progress_response.status_code == 200
        
        # Complete session
        complete_response = await client.post(f"/api/v1/sessions/{session_id}/complete")
        assert complete_response.status_code == 200

def test_session_not_found(client):
    response = client.get("/api/v1/sessions/nonexistent")
    assert response.status_code == 404
EOF

# Create test runner script
cat > scripts/run_tests.py << 'EOF'
#!/usr/bin/env python3

import subprocess
import sys
import asyncio
import time

def run_command(cmd, description):
    print(f"\n🔍 {description}")
    print(f"Running: {cmd}")
    result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    
    if result.returncode == 0:
        print(f"✅ {description} - SUCCESS")
        if result.stdout:
            print(f"Output: {result.stdout[:500]}")
    else:
        print(f"❌ {description} - FAILED")
        print(f"Error: {result.stderr}")
        return False
    return True

async def main():
    print("🧪 Running Quiz Session Management Tests")
    
    tests = [
        ("python3 -m pytest tests/unit/ -v", "Unit Tests"),
        ("python3 -m pytest tests/integration/ -v", "Integration Tests"),
        ("python3 -c \"import src.models.attempt; print('✅ Models import OK')\"", "Model Validation"),
        ("python3 -c \"import src.services.session_manager; print('✅ Services import OK')\"", "Service Validation"),
    ]
    
    all_passed = True
    for cmd, desc in tests:
        if not run_command(cmd, desc):
            all_passed = False
    
    if all_passed:
        print("\n🎉 All tests passed! System is ready for deployment.")
    else:
        print("\n⚠️  Some tests failed. Check the output above.")
        sys.exit(1)

if __name__ == "__main__":
    asyncio.run(main())
EOF

chmod +x scripts/run_tests.py

# Create __init__.py files for proper Python package structure
touch src/__init__.py
touch src/models/__init__.py
touch src/services/__init__.py
touch src/api/__init__.py
touch src/utils/__init__.py
touch tests/__init__.py
touch tests/unit/__init__.py
touch tests/integration/__init__.py

echo "📦 Setting up virtual environment..."
# Remove existing venv if it exists
rm -rf venv

# Create new venv with the correct Python version
$PYTHON_CMD -m venv venv

# Activate virtual environment and ensure we're using the venv's Python
source venv/bin/activate
PYTHON_CMD=python  # Use the venv's Python

echo "📦 Installing dependencies..."
$PYTHON_CMD -m pip install --upgrade pip
$PYTHON_CMD -m pip install -r requirements.txt

# Set PYTHONPATH for proper imports
export PYTHONPATH="${PYTHONPATH}:$(pwd)/src"

echo "🧪 Running tests..."
$PYTHON_CMD scripts/run_tests.py

echo "🐳 Building Docker containers..."
docker-compose build

echo "🚀 Starting services..."
docker-compose up -d

echo "✨ Setup complete! The service is running at http://localhost:8002"