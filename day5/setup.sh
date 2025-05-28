#!/bin/bash

# Quiz Service Data Layer - One-Click Setup Script
# Day 5: Repository Pattern Implementation

set -e  # Exit on any error

echo "🚀 Starting Quiz Service Data Layer Setup..."

# Create project structure
echo "📁 Creating project structure..."
mkdir -p quiz-service/{src/{models,repositories,services,database,tests},config,docker,scripts}

# Navigate to project directory
cd quiz-service

# Create virtual environment
echo "🐍 Setting up Python environment..."
python3.12 -m venv venv
source venv/bin/activate

# Install dependencies
echo "📦 Installing dependencies..."
cat > requirements.txt << 'EOF'
fastapi==0.104.1
uvicorn==0.24.0
sqlalchemy==2.0.23
asyncpg==0.29.0
redis==5.0.1
pydantic==2.5.0
pytest==7.4.3
pytest-asyncio==0.21.1
python-jose[cryptography]==3.3.0
passlib[bcrypt]==1.7.4
python-multipart==0.0.6
alembic==1.12.1
httpx==0.25.2
EOF

pip install -r requirements.txt

# Database configuration
echo "🗄️ Creating database configuration..."
cat > config/database.py << 'EOF'
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
EOF

# Quiz models
echo "📋 Creating quiz models..."
cat > src/models/quiz.py << 'EOF'
from sqlalchemy import Column, Integer, String, Text, DateTime, Boolean, ForeignKey, Index
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from config.database import Base
from pydantic import BaseModel
from typing import List, Optional
from datetime import datetime

# SQLAlchemy Models
class Quiz(Base):
    __tablename__ = "quizzes"
    
    id = Column(Integer, primary_key=True, index=True)
    title = Column(String(255), nullable=False, index=True)
    description = Column(Text)
    category = Column(String(100), index=True)
    difficulty = Column(String(20), index=True)
    is_active = Column(Boolean, default=True, index=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    
    # Relationship to questions
    questions = relationship("Question", back_populates="quiz", cascade="all, delete-orphan")
    
    # Indexes for optimized queries
    __table_args__ = (
        Index('idx_quiz_category_difficulty', 'category', 'difficulty'),
        Index('idx_quiz_active_created', 'is_active', 'created_at'),
    )

class Question(Base):
    __tablename__ = "questions"
    
    id = Column(Integer, primary_key=True, index=True)
    quiz_id = Column(Integer, ForeignKey("quizzes.id"), nullable=False, index=True)
    question_text = Column(Text, nullable=False)
    question_type = Column(String(50), default="multiple_choice")
    points = Column(Integer, default=1)
    order_index = Column(Integer, default=0)
    
    # Relationship
    quiz = relationship("Quiz", back_populates="questions")
    answers = relationship("Answer", back_populates="question", cascade="all, delete-orphan")

class Answer(Base):
    __tablename__ = "answers"
    
    id = Column(Integer, primary_key=True, index=True)
    question_id = Column(Integer, ForeignKey("questions.id"), nullable=False, index=True)
    answer_text = Column(Text, nullable=False)
    is_correct = Column(Boolean, default=False)
    order_index = Column(Integer, default=0)
    
    # Relationship
    question = relationship("Question", back_populates="answers")

# Pydantic Models for API
class AnswerBase(BaseModel):
    answer_text: str
    is_correct: bool
    order_index: int = 0

class AnswerCreate(AnswerBase):
    pass

class AnswerResponse(AnswerBase):
    id: int
    question_id: int
    
    class Config:
        from_attributes = True

class QuestionBase(BaseModel):
    question_text: str
    question_type: str = "multiple_choice"
    points: int = 1
    order_index: int = 0

class QuestionCreate(QuestionBase):
    answers: List[AnswerCreate] = []

class QuestionResponse(QuestionBase):
    id: int
    quiz_id: int
    answers: List[AnswerResponse] = []
    
    class Config:
        from_attributes = True

class QuizBase(BaseModel):
    title: str
    description: Optional[str] = None
    category: str
    difficulty: str = "medium"
    is_active: bool = True

class QuizCreate(QuizBase):
    questions: List[QuestionCreate] = []

class QuizUpdate(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    category: Optional[str] = None
    difficulty: Optional[str] = None
    is_active: Optional[bool] = None

class QuizResponse(QuizBase):
    id: int
    created_at: datetime
    updated_at: Optional[datetime] = None
    questions: List[QuestionResponse] = []
    
    class Config:
        from_attributes = True

class QuizSummary(BaseModel):
    id: int
    title: str
    category: str
    difficulty: str
    question_count: int
    created_at: datetime
    
    class Config:
        from_attributes = True
EOF

# Repository implementation
echo "🏗️ Creating quiz repository..."
cat > src/repositories/quiz_repository.py << 'EOF'
from typing import List, Optional, Dict, Any
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, and_, or_
from sqlalchemy.orm import selectinload
import json
import redis.asyncio as redis
from src.models.quiz import Quiz, Question, Answer, QuizCreate, QuizUpdate, QuizResponse, QuizSummary

class QuizRepository:
    def __init__(self, db: AsyncSession, redis_client: redis.Redis):
        self.db = db
        self.redis = redis_client
        self.cache_ttl = 3600  # 1 hour cache TTL
    
    async def create_quiz(self, quiz_data: QuizCreate) -> Quiz:
        """Create a new quiz with questions and answers"""
        db_quiz = Quiz(
            title=quiz_data.title,
            description=quiz_data.description,
            category=quiz_data.category,
            difficulty=quiz_data.difficulty,
            is_active=quiz_data.is_active
        )
        
        self.db.add(db_quiz)
        await self.db.flush()  # Get the quiz ID
        
        # Add questions and answers
        for question_data in quiz_data.questions:
            db_question = Question(
                quiz_id=db_quiz.id,
                question_text=question_data.question_text,
                question_type=question_data.question_type,
                points=question_data.points,
                order_index=question_data.order_index
            )
            self.db.add(db_question)
            await self.db.flush()  # Get question ID
            
            # Add answers
            for answer_data in question_data.answers:
                db_answer = Answer(
                    question_id=db_question.id,
                    answer_text=answer_data.answer_text,
                    is_correct=answer_data.is_correct,
                    order_index=answer_data.order_index
                )
                self.db.add(db_answer)
        
        await self.db.commit()
        await self.db.refresh(db_quiz)
        
        # Invalidate related caches
        await self._invalidate_quiz_caches(db_quiz.category)
        
        return db_quiz
    
    async def get_quiz_by_id(self, quiz_id: int) -> Optional[Quiz]:
        """Get quiz by ID with optimized caching"""
        cache_key = f"quiz:{quiz_id}"
        
        # Try cache first
        cached_quiz = await self.redis.get(cache_key)
        if cached_quiz:
            return Quiz(**json.loads(cached_quiz))
        
        # Query database with eager loading
        stmt = (
            select(Quiz)
            .options(
                selectinload(Quiz.questions).selectinload(Question.answers)
            )
            .where(Quiz.id == quiz_id)
        )
        result = await self.db.execute(stmt)
        quiz = result.scalar_one_or_none()
        
        # Cache the result
        if quiz:
            quiz_dict = {
                "id": quiz.id,
                "title": quiz.title,
                "description": quiz.description,
                "category": quiz.category,
                "difficulty": quiz.difficulty,
                "is_active": quiz.is_active,
                "created_at": quiz.created_at.isoformat(),
                "updated_at": quiz.updated_at.isoformat() if quiz.updated_at else None
            }
            await self.redis.setex(cache_key, self.cache_ttl, json.dumps(quiz_dict))
        
        return quiz
    
    async def get_quizzes(
        self,
        skip: int = 0,
        limit: int = 20,
        category: Optional[str] = None,
        difficulty: Optional[str] = None,
        is_active: bool = True
    ) -> List[QuizSummary]:
        """Get quizzes with filtering and pagination"""
        
        # Build cache key for this query
        cache_key = f"quizzes:{skip}:{limit}:{category}:{difficulty}:{is_active}"
        
        # Try cache first
        cached_quizzes = await self.redis.get(cache_key)
        if cached_quizzes:
            quiz_data = json.loads(cached_quizzes)
            return [QuizSummary(**quiz) for quiz in quiz_data]
        
        # Build query
        stmt = select(Quiz).where(Quiz.is_active == is_active)
        
        if category:
            stmt = stmt.where(Quiz.category == category)
        if difficulty:
            stmt = stmt.where(Quiz.difficulty == difficulty)
        
        stmt = stmt.order_by(Quiz.created_at.desc()).offset(skip).limit(limit)
        
        result = await self.db.execute(stmt)
        quizzes = result.scalars().all()
        
        # Get question counts for each quiz
        quiz_summaries = []
        for quiz in quizzes:
            question_count_stmt = select(func.count(Question.id)).where(Question.quiz_id == quiz.id)
            question_count_result = await self.db.execute(question_count_stmt)
            question_count = question_count_result.scalar()
            
            quiz_summaries.append(QuizSummary(
                id=quiz.id,
                title=quiz.title,
                category=quiz.category,
                difficulty=quiz.difficulty,
                question_count=question_count,
                created_at=quiz.created_at
            ))
        
        # Cache the results
        quiz_data = [quiz.dict() for quiz in quiz_summaries]
        await self.redis.setex(cache_key, self.cache_ttl, json.dumps(quiz_data))
        
        return quiz_summaries
    
    async def update_quiz(self, quiz_id: int, quiz_data: QuizUpdate) -> Optional[Quiz]:
        """Update quiz with cache invalidation"""
        stmt = select(Quiz).where(Quiz.id == quiz_id)
        result = await self.db.execute(stmt)
        quiz = result.scalar_one_or_none()
        
        if not quiz:
            return None
        
        # Update fields
        update_data = quiz_data.dict(exclude_unset=True)
        for field, value in update_data.items():
            setattr(quiz, field, value)
        
        await self.db.commit()
        await self.db.refresh(quiz)
        
        # Invalidate caches
        await self._invalidate_quiz_caches(quiz.category)
        await self.redis.delete(f"quiz:{quiz_id}")
        
        return quiz
    
    async def delete_quiz(self, quiz_id: int) -> bool:
        """Soft delete quiz"""
        stmt = select(Quiz).where(Quiz.id == quiz_id)
        result = await self.db.execute(stmt)
        quiz = result.scalar_one_or_none()
        
        if not quiz:
            return False
        
        quiz.is_active = False
        await self.db.commit()
        
        # Invalidate caches
        await self._invalidate_quiz_caches(quiz.category)
        await self.redis.delete(f"quiz:{quiz_id}")
        
        return True
    
    async def search_quizzes(self, query: str, limit: int = 10) -> List[QuizSummary]:
        """Full-text search across quiz titles and descriptions"""
        cache_key = f"search:{query}:{limit}"
        
        # Try cache first
        cached_results = await self.redis.get(cache_key)
        if cached_results:
            quiz_data = json.loads(cached_results)
            return [QuizSummary(**quiz) for quiz in quiz_data]
        
        # Database search
        search_term = f"%{query}%"
        stmt = (
            select(Quiz)
            .where(
                and_(
                    Quiz.is_active == True,
                    or_(
                        Quiz.title.ilike(search_term),
                        Quiz.description.ilike(search_term)
                    )
                )
            )
            .order_by(Quiz.created_at.desc())
            .limit(limit)
        )
        
        result = await self.db.execute(stmt)
        quizzes = result.scalars().all()
        
        # Build summary results
        quiz_summaries = []
        for quiz in quizzes:
            question_count_stmt = select(func.count(Question.id)).where(Question.quiz_id == quiz.id)
            question_count_result = await self.db.execute(question_count_stmt)
            question_count = question_count_result.scalar()
            
            quiz_summaries.append(QuizSummary(
                id=quiz.id,
                title=quiz.title,
                category=quiz.category,
                difficulty=quiz.difficulty,
                question_count=question_count,
                created_at=quiz.created_at
            ))
        
        # Cache results
        quiz_data = [quiz.dict() for quiz in quiz_summaries]
        await self.redis.setex(cache_key, 1800, json.dumps(quiz_data))  # 30 min cache for search
        
        return quiz_summaries
    
    async def get_quiz_statistics(self) -> Dict[str, Any]:
        """Get overall quiz statistics"""
        cache_key = "quiz_stats"
        
        # Try cache first
        cached_stats = await self.redis.get(cache_key)
        if cached_stats:
            return json.loads(cached_stats)
        
        # Calculate statistics
        total_quizzes_stmt = select(func.count(Quiz.id)).where(Quiz.is_active == True)
        total_quizzes = await self.db.execute(total_quizzes_stmt)
        
        category_stats_stmt = (
            select(Quiz.category, func.count(Quiz.id))
            .where(Quiz.is_active == True)
            .group_by(Quiz.category)
        )
        category_stats = await self.db.execute(category_stats_stmt)
        
        difficulty_stats_stmt = (
            select(Quiz.difficulty, func.count(Quiz.id))
            .where(Quiz.is_active == True)
            .group_by(Quiz.difficulty)
        )
        difficulty_stats = await self.db.execute(difficulty_stats_stmt)
        
        stats = {
            "total_quizzes": total_quizzes.scalar(),
            "by_category": dict(category_stats.fetchall()),
            "by_difficulty": dict(difficulty_stats.fetchall())
        }
        
        # Cache for 10 minutes
        await self.redis.setex(cache_key, 600, json.dumps(stats))
        
        return stats
    
    async def _invalidate_quiz_caches(self, category: str):
        """Helper to invalidate related caches"""
        patterns = [
            "quizzes:*",
            f"search:*",
            "quiz_stats"
        ]
        
        for pattern in patterns:
            keys = await self.redis.keys(pattern)
            if keys:
                await self.redis.delete(*keys)
EOF

# Service layer
echo "⚙️ Creating quiz service..."
cat > src/services/quiz_service.py << 'EOF'
from typing import List, Optional
from fastapi import Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
import redis.asyncio as redis

from config.database import get_db, get_redis
from src.repositories.quiz_repository import QuizRepository
from src.models.quiz import QuizCreate, QuizUpdate, QuizResponse, QuizSummary

class QuizService:
    def __init__(self, db: AsyncSession = Depends(get_db), redis_client: redis.Redis = Depends(get_redis)):
        self.repository = QuizRepository(db, redis_client)
    
    async def create_quiz(self, quiz_data: QuizCreate) -> QuizResponse:
        """Create a new quiz"""
        try:
            quiz = await self.repository.create_quiz(quiz_data)
            return QuizResponse.from_orm(quiz)
        except Exception as e:
            raise HTTPException(status_code=400, detail=f"Failed to create quiz: {str(e)}")
    
    async def get_quiz(self, quiz_id: int) -> QuizResponse:
        """Get quiz by ID"""
        quiz = await self.repository.get_quiz_by_id(quiz_id)
        if not quiz:
            raise HTTPException(status_code=404, detail="Quiz not found")
        return QuizResponse.from_orm(quiz)
    
    async def get_quizzes(
        self,
        skip: int = 0,
        limit: int = 20,
        category: Optional[str] = None,
        difficulty: Optional[str] = None
    ) -> List[QuizSummary]:
        """Get list of quizzes with filtering"""
        return await self.repository.get_quizzes(skip, limit, category, difficulty)
    
    async def update_quiz(self, quiz_id: int, quiz_data: QuizUpdate) -> QuizResponse:
        """Update existing quiz"""
        quiz = await self.repository.update_quiz(quiz_id, quiz_data)
        if not quiz:
            raise HTTPException(status_code=404, detail="Quiz not found")
        return QuizResponse.from_orm(quiz)
    
    async def delete_quiz(self, quiz_id: int) -> bool:
        """Delete quiz"""
        success = await self.repository.delete_quiz(quiz_id)
        if not success:
            raise HTTPException(status_code=404, detail="Quiz not found")
        return success
    
    async def search_quizzes(self, query: str, limit: int = 10) -> List[QuizSummary]:
        """Search quizzes"""
        if not query.strip():
            raise HTTPException(status_code=400, detail="Search query cannot be empty")
        return await self.repository.search_quizzes(query, limit)
    
    async def get_statistics(self):
        """Get quiz statistics"""
        return await self.repository.get_quiz_statistics()
EOF

# Database migration
echo "🗄️ Creating database migration..."
mkdir -p src/database/migrations
cat > src/database/migrations/create_tables.py << 'EOF'
"""Create quiz tables with optimized indexes"""

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

def upgrade():
    # Create quizzes table
    op.create_table(
        'quizzes',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('title', sa.String(length=255), nullable=False),
        sa.Column('description', sa.Text()),
        sa.Column('category', sa.String(length=100)),
        sa.Column('difficulty', sa.String(length=20)),
        sa.Column('is_active', sa.Boolean(), default=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column('updated_at', sa.DateTime(timezone=True)),
        sa.PrimaryKeyConstraint('id')
    )
    
    # Create optimized indexes
    op.create_index('ix_quizzes_id', 'quizzes', ['id'])
    op.create_index('ix_quizzes_title', 'quizzes', ['title'])
    op.create_index('ix_quizzes_category', 'quizzes', ['category'])
    op.create_index('ix_quizzes_difficulty', 'quizzes', ['difficulty'])
    op.create_index('ix_quizzes_is_active', 'quizzes', ['is_active'])
    op.create_index('idx_quiz_category_difficulty', 'quizzes', ['category', 'difficulty'])
    op.create_index('idx_quiz_active_created', 'quizzes', ['is_active', 'created_at'])
    
    # Create questions table
    op.create_table(
        'questions',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('quiz_id', sa.Integer(), nullable=False),
        sa.Column('question_text', sa.Text(), nullable=False),
        sa.Column('question_type', sa.String(length=50), default='multiple_choice'),
        sa.Column('points', sa.Integer(), default=1),
        sa.Column('order_index', sa.Integer(), default=0),
        sa.PrimaryKeyConstraint('id'),
        sa.ForeignKeyConstraint(['quiz_id'], ['quizzes.id'])
    )
    
    op.create_index('ix_questions_id', 'questions', ['id'])
    op.create_index('ix_questions_quiz_id', 'questions', ['quiz_id'])
    
    # Create answers table
    op.create_table(
        'answers',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('question_id', sa.Integer(), nullable=False),
        sa.Column('answer_text', sa.Text(), nullable=False),
        sa.Column('is_correct', sa.Boolean(), default=False),
        sa.Column('order_index', sa.Integer(), default=0),
        sa.PrimaryKeyConstraint('id'),
        sa.ForeignKeyConstraint(['question_id'], ['questions.id'])
    )
    
    op.create_index('ix_answers_id', 'answers', ['id'])
    op.create_index('ix_answers_question_id', 'answers', ['question_id'])

def downgrade():
    op.drop_table('answers')
    op.drop_table('questions')
    op.drop_table('quizzes')
EOF

# Create API endpoints
echo "🌐 Creating API endpoints..."
cat > src/main.py << 'EOF'
from fastapi import FastAPI, Depends, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from typing import List, Optional
import uvicorn

from src.services.quiz_service import QuizService
from src.models.quiz import QuizCreate, QuizUpdate, QuizResponse, QuizSummary

app = FastAPI(
    title="Quiz Service API",
    description="High-performance quiz data service with repository pattern",
    version="1.0.0"
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.post("/quizzes/", response_model=QuizResponse, status_code=201)
async def create_quiz(
    quiz_data: QuizCreate,
    quiz_service: QuizService = Depends()
):
    """Create a new quiz with questions and answers"""
    return await quiz_service.create_quiz(quiz_data)

@app.get("/quizzes/{quiz_id}", response_model=QuizResponse)
async def get_quiz(
    quiz_id: int,
    quiz_service: QuizService = Depends()
):
    """Get a specific quiz by ID"""
    return await quiz_service.get_quiz(quiz_id)

@app.get("/quizzes/", response_model=List[QuizSummary])
async def get_quizzes(
    skip: int = Query(0, ge=0, description="Number of quizzes to skip"),
    limit: int = Query(20, ge=1, le=100, description="Number of quizzes to return"),
    category: Optional[str] = Query(None, description="Filter by category"),
    difficulty: Optional[str] = Query(None, description="Filter by difficulty"),
    quiz_service: QuizService = Depends()
):
    """Get list of quizzes with filtering and pagination"""
    return await quiz_service.get_quizzes(skip, limit, category, difficulty)

@app.put("/quizzes/{quiz_id}", response_model=QuizResponse)
async def update_quiz(
    quiz_id: int,
    quiz_data: QuizUpdate,
    quiz_service: QuizService = Depends()
):
    """Update an existing quiz"""
    return await quiz_service.update_quiz(quiz_id, quiz_data)

@app.delete("/quizzes/{quiz_id}")
async def delete_quiz(
    quiz_id: int,
    quiz_service: QuizService = Depends()
):
    """Delete a quiz (soft delete)"""
    success = await quiz_service.delete_quiz(quiz_id)
    return {"message": "Quiz deleted successfully", "success": success}

@app.get("/quizzes/search/", response_model=List[QuizSummary])
async def search_quizzes(
    q: str = Query(..., min_length=1, description="Search query"),
    limit: int = Query(10, ge=1, le=50, description="Number of results to return"),
    quiz_service: QuizService = Depends()
):
    """Search quizzes by title or description"""
    return await quiz_service.search_quizzes(q, limit)

@app.get("/quizzes/stats/")
async def get_quiz_statistics(quiz_service: QuizService = Depends()):
    """Get quiz statistics and analytics"""
    return await quiz_service.get_statistics()

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {"status": "healthy", "service": "quiz-data-layer"}

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000, reload=True)
EOF

# Create comprehensive tests
echo "🧪 Creating test files..."
cat > src/tests/test_quiz_repository.py << 'EOF'
import pytest
import pytest_asyncio
import asyncio
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy.orm import sessionmaker
import redis.asyncio as redis

from config.database import Base
from src.repositories.quiz_repository import QuizRepository
from src.models.quiz import QuizCreate, QuestionCreate, AnswerCreate

# Test database setup
TEST_DATABASE_URL = "postgresql+asyncpg://quiz_user:quiz_pass@localhost:5432/quiz_test_db"
TEST_REDIS_URL = "redis://localhost:6379/1"

@pytest_asyncio.fixture
async def db_session():
    engine = create_async_engine(TEST_DATABASE_URL, echo=False)
    
    # Create tables
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    
    AsyncTestSession = sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)
    
    async with AsyncTestSession() as session:
        yield session
    
    # Clean up
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)
    
    await engine.dispose()

@pytest_asyncio.fixture
async def redis_client():
    client = redis.from_url(TEST_REDIS_URL, decode_responses=True)
    await client.flushdb()  # Clear test database
    yield client
    await client.flushdb()
    await client.close()

@pytest_asyncio.fixture
async def quiz_repository(db_session, redis_client):
    return QuizRepository(db_session, redis_client)

@pytest_asyncio.fixture
def sample_quiz_data():
    return QuizCreate(
        title="Python Basics Quiz",
        description="Test your Python knowledge",
        category="Programming",
        difficulty="beginner",
        questions=[
            QuestionCreate(
                question_text="What is Python?",
                question_type="multiple_choice",
                points=5,
                order_index=1,
                answers=[
                    AnswerCreate(answer_text="A snake", is_correct=False, order_index=1),
                    AnswerCreate(answer_text="A programming language", is_correct=True, order_index=2),
                    AnswerCreate(answer_text="A web framework", is_correct=False, order_index=3),
                ]
            ),
            QuestionCreate(
                question_text="Python is interpreted language?",
                question_type="true_false",
                points=3,
                order_index=2,
                answers=[
                    AnswerCreate(answer_text="True", is_correct=True, order_index=1),
                    AnswerCreate(answer_text="False", is_correct=False, order_index=2),
                ]
            )
        ]
    )

class TestQuizRepository:
    
    @pytest.mark.asyncio
    async def test_create_quiz(self, quiz_repository, sample_quiz_data):
        """Test creating a new quiz"""
        quiz = await quiz_repository.create_quiz(sample_quiz_data)
        
        assert quiz.id is not None
        assert quiz.title == "Python Basics Quiz"
        assert quiz.category == "Programming"
        assert quiz.difficulty == "beginner"
        assert len(quiz.questions) == 2
        assert quiz.questions[0].question_text == "What is Python?"
        assert len(quiz.questions[0].answers) == 3
    
    @pytest.mark.asyncio
    async def test_get_quiz_by_id(self, quiz_repository, sample_quiz_data):
        """Test retrieving quiz by ID"""
        # Create quiz
        created_quiz = await quiz_repository.create_quiz(sample_quiz_data)
        
        # Retrieve quiz
        retrieved_quiz = await quiz_repository.get_quiz_by_id(created_quiz.id)
        
        assert retrieved_quiz is not None
        assert retrieved_quiz.id == created_quiz.id
        assert retrieved_quiz.title == created_quiz.title
    
    @pytest.mark.asyncio
    async def test_get_quiz_by_id_not_found(self, quiz_repository):
        """Test retrieving non-existent quiz"""
        quiz = await quiz_repository.get_quiz_by_id(999)
        assert quiz is None
    
    @pytest.mark.asyncio
    async def test_get_quizzes_pagination(self, quiz_repository, sample_quiz_data):
        """Test getting quizzes with pagination"""
        # Create multiple quizzes
        for i in range(5):
            quiz_data = sample_quiz_data.copy()
            quiz_data.title = f"Quiz {i}"
            await quiz_repository.create_quiz(quiz_data)
        
        # Test pagination
        quizzes_page1 = await quiz_repository.get_quizzes(skip=0, limit=3)
        quizzes_page2 = await quiz_repository.get_quizzes(skip=3, limit=3)
        
        assert len(quizzes_page1) == 3
        assert len(quizzes_page2) == 2
        
        # Ensure no duplicates
        page1_ids = {quiz.id for quiz in quizzes_page1}
        page2_ids = {quiz.id for quiz in quizzes_page2}
        assert len(page1_ids.intersection(page2_ids)) == 0
    
    @pytest.mark.asyncio
    async def test_get_quizzes_filtering(self, quiz_repository, sample_quiz_data):
        """Test filtering quizzes by category and difficulty"""
        # Create quizzes with different categories
        quiz_data_1 = sample_quiz_data.copy()
        quiz_data_1.category = "Math"
        quiz_data_1.difficulty = "easy"
        await quiz_repository.create_quiz(quiz_data_1)
        
        quiz_data_2 = sample_quiz_data.copy()
        quiz_data_2.category = "Programming"
        quiz_data_2.difficulty = "hard"
        await quiz_repository.create_quiz(quiz_data_2)
        
        # Test category filtering
        math_quizzes = await quiz_repository.get_quizzes(category="Math")
        assert len(math_quizzes) == 1
        assert math_quizzes[0].category == "Math"
        
        # Test difficulty filtering
        easy_quizzes = await quiz_repository.get_quizzes(difficulty="easy")
        assert len(easy_quizzes) == 1
        assert easy_quizzes[0].difficulty == "easy"
        
        # Test combined filtering
        hard_programming = await quiz_repository.get_quizzes(
            category="Programming", 
            difficulty="hard"
        )
        assert len(hard_programming) == 1
    
    @pytest.mark.asyncio
    async def test_update_quiz(self, quiz_repository, sample_quiz_data):
        """Test updating quiz"""
        from src.models.quiz import QuizUpdate
        
        # Create quiz
        quiz = await quiz_repository.create_quiz(sample_quiz_data)
        
        # Update quiz
        update_data = QuizUpdate(
            title="Updated Python Quiz",
            difficulty="intermediate"
        )
        updated_quiz = await quiz_repository.update_quiz(quiz.id, update_data)
        
        assert updated_quiz is not None
        assert updated_quiz.title == "Updated Python Quiz"
        assert updated_quiz.difficulty == "intermediate"
        assert updated_quiz.category == "Programming"  # Should remain unchanged
    
    @pytest.mark.asyncio
    async def test_delete_quiz(self, quiz_repository, sample_quiz_data):
        """Test soft deleting quiz"""
        # Create quiz
        quiz = await quiz_repository.create_quiz(sample_quiz_data)
        
        # Delete quiz
        success = await quiz_repository.delete_quiz(quiz.id)
        assert success is True
        
        # Verify quiz is soft deleted (not active)
        deleted_quiz = await quiz_repository.get_quiz_by_id(quiz.id)
        assert deleted_quiz.is_active is False
    
    @pytest.mark.asyncio
    async def test_search_quizzes(self, quiz_repository, sample_quiz_data):
        """Test searching quizzes"""
        # Create quizzes with different titles
        quiz_data_1 = sample_quiz_data.copy()
        quiz_data_1.title = "Python Advanced Concepts"
        await quiz_repository.create_quiz(quiz_data_1)
        
        quiz_data_2 = sample_quiz_data.copy()
        quiz_data_2.title = "JavaScript Fundamentals"
        await quiz_repository.create_quiz(quiz_data_2)
        
        # Search for Python quizzes
        python_quizzes = await quiz_repository.search_quizzes("Python")
        assert len(python_quizzes) == 1
        assert "Python" in python_quizzes[0].title
        
        # Search for programming quizzes
        programming_quizzes = await quiz_repository.search_quizzes("programming")
        assert len(programming_quizzes) >= 1
    
    @pytest.mark.asyncio
    async def test_get_quiz_statistics(self, quiz_repository, sample_quiz_data):
        """Test getting quiz statistics"""
        # Create multiple quizzes
        for category, difficulty in [("Math", "easy"), ("Programming", "hard"), ("Math", "medium")]:
            quiz_data = sample_quiz_data.copy()
            quiz_data.category = category
            quiz_data.difficulty = difficulty
            await quiz_repository.create_quiz(quiz_data)
        
        # Get statistics
        stats = await quiz_repository.get_quiz_statistics()
        
        assert "total_quizzes" in stats
        assert "by_category" in stats
        assert "by_difficulty" in stats
        assert stats["total_quizzes"] == 3
        assert stats["by_category"]["Math"] == 2
        assert stats["by_category"]["Programming"] == 1
    
    @pytest.mark.asyncio
    async def test_caching_behavior(self, quiz_repository, sample_quiz_data, redis_client):
        """Test Redis caching functionality"""
        # Create quiz
        quiz = await quiz_repository.create_quiz(sample_quiz_data)
        
        # First call should cache the result
        cached_quiz = await quiz_repository.get_quiz_by_id(quiz.id)
        
        # Check if quiz is cached in Redis
        cache_key = f"quiz:{quiz.id}"
        cached_data = await redis_client.get(cache_key)
        assert cached_data is not None
        
        # Second call should use cache
        cached_quiz_2 = await quiz_repository.get_quiz_by_id(quiz.id)
        assert cached_quiz.id == cached_quiz_2.id

if __name__ == "__main__":
    pytest.main([__file__, "-v"])
EOF

# Create integration tests
echo "🔄 Creating integration tests..."
cat > src/tests/test_integration.py << 'EOF'
import pytest
import pytest_asyncio
from httpx import AsyncClient
from fastapi.testclient import TestClient
import asyncio

from src.main import app
from src.models.quiz import QuizCreate, QuestionCreate, AnswerCreate

@pytest.fixture
def sample_quiz_payload():
    return {
        "title": "Integration Test Quiz",
        "description": "Testing API endpoints",
        "category": "Testing",
        "difficulty": "medium",
        "questions": [
            {
                "question_text": "What is integration testing?",
                "question_type": "multiple_choice",
                "points": 5,
                "order_index": 1,
                "answers": [
                    {"answer_text": "Testing individual components", "is_correct": False, "order_index": 1},
                    {"answer_text": "Testing component interactions", "is_correct": True, "order_index": 2},
                    {"answer_text": "Testing user interface", "is_correct": False, "order_index": 3}
                ]
            }
        ]
    }

class TestQuizAPI:
    
    @pytest.mark.asyncio
    async def test_create_quiz_endpoint(self, sample_quiz_payload):
        """Test creating quiz via API"""
        async with AsyncClient(app=app, base_url="http://test") as client:
            response = await client.post("/quizzes/", json=sample_quiz_payload)
            
            assert response.status_code == 201
            data = response.json()
            assert data["title"] == "Integration Test Quiz"
            assert data["category"] == "Testing"
            assert len(data["questions"]) == 1
    
    @pytest.mark.asyncio
    async def test_get_quiz_endpoint(self, sample_quiz_payload):
        """Test getting quiz via API"""
        async with AsyncClient(app=app, base_url="http://test") as client:
            # Create quiz first
            create_response = await client.post("/quizzes/", json=sample_quiz_payload)
            created_quiz = create_response.json()
            quiz_id = created_quiz["id"]
            
            # Get quiz
            get_response = await client.get(f"/quizzes/{quiz_id}")
            
            assert get_response.status_code == 200
            data = get_response.json()
            assert data["id"] == quiz_id
            assert data["title"] == "Integration Test Quiz"
    
    @pytest.mark.asyncio
    async def test_get_quizzes_with_filters(self, sample_quiz_payload):
        """Test getting quizzes with filtering"""
        async with AsyncClient(app=app, base_url="http://test") as client:
            # Create multiple quizzes
            for i in range(3):
                quiz_data = sample_quiz_payload.copy()
                quiz_data["title"] = f"Test Quiz {i}"
                quiz_data["category"] = "Testing" if i < 2 else "Programming"
                await client.post("/quizzes/", json=quiz_data)
            
            # Test without filters
            response = await client.get("/quizzes/")
            assert response.status_code == 200
            data = response.json()
            assert len(data) == 3
            
            # Test with category filter
            response = await client.get("/quizzes/?category=Testing")
            assert response.status_code == 200
            data = response.json()
            assert len(data) == 2
            
            # Test with pagination
            response = await client.get("/quizzes/?skip=0&limit=2")
            assert response.status_code == 200
            data = response.json()
            assert len(data) == 2
    
    @pytest.mark.asyncio
    async def test_search_quizzes_endpoint(self, sample_quiz_payload):
        """Test searching quizzes"""
        async with AsyncClient(app=app, base_url="http://test") as client:
            # Create quiz
            await client.post("/quizzes/", json=sample_quiz_payload)
            
            # Search
            response = await client.get("/quizzes/search/?q=Integration")
            
            assert response.status_code == 200
            data = response.json()
            assert len(data) >= 1
            assert "Integration" in data[0]["title"]
    
    @pytest.mark.asyncio
    async def test_update_quiz_endpoint(self, sample_quiz_payload):
        """Test updating quiz via API"""
        async with AsyncClient(app=app, base_url="http://test") as client:
            # Create quiz
            create_response = await client.post("/quizzes/", json=sample_quiz_payload)
            quiz_id = create_response.json()["id"]
            
            # Update quiz
            update_data = {
                "title": "Updated Integration Test Quiz",
                "difficulty": "hard"
            }
            update_response = await client.put(f"/quizzes/{quiz_id}", json=update_data)
            
            assert update_response.status_code == 200
            data = update_response.json()
            assert data["title"] == "Updated Integration Test Quiz"
            assert data["difficulty"] == "hard"
    
    @pytest.mark.asyncio
    async def test_delete_quiz_endpoint(self, sample_quiz_payload):
        """Test deleting quiz via API"""
        async with AsyncClient(app=app, base_url="http://test") as client:
            # Create quiz
            create_response = await client.post("/quizzes/", json=sample_quiz_payload)
            quiz_id = create_response.json()["id"]
            
            # Delete quiz
            delete_response = await client.delete(f"/quizzes/{quiz_id}")
            
            assert delete_response.status_code == 200
            data = delete_response.json()
            assert data["success"] is True
    
    @pytest.mark.asyncio
    async def test_quiz_statistics_endpoint(self, sample_quiz_payload):
        """Test getting quiz statistics"""
        async with AsyncClient(app=app, base_url="http://test") as client:
            # Create a few quizzes
            for i in range(2):
                await client.post("/quizzes/", json=sample_quiz_payload)
            
            # Get statistics
            response = await client.get("/quizzes/stats/")
            
            assert response.status_code == 200
            data = response.json()
            assert "total_quizzes" in data
            assert data["total_quizzes"] >= 2
    
    @pytest.mark.asyncio
    async def test_health_check(self):
        """Test health check endpoint"""
        async with AsyncClient(app=app, base_url="http://test") as client:
            response = await client.get("/health")
            
            assert response.status_code == 200
            data = response.json()
            assert data["status"] == "healthy"

if __name__ == "__main__":
    pytest.main([__file__, "-v"])
EOF

# Docker configuration
echo "🐳 Creating Docker configuration..."
cat > docker/Dockerfile << 'EOF'
FROM python:3.12-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements and install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Expose port
EXPOSE 8000

# Command to run the application
CMD ["uvicorn", "src.main:app", "--host", "0.0.0.0", "--port", "8000", "--reload"]
EOF

cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  quiz-api:
    build:
      context: .
      dockerfile: docker/Dockerfile
    ports:
      - "8000:8000"
    environment:
      - DATABASE_URL=postgresql+asyncpg://quiz_user:quiz_pass@postgres:5432/quiz_db
      - REDIS_URL=redis://redis:6379
    depends_on:
      - postgres
      - redis
    volumes:
      - .:/app
    command: uvicorn src.main:app --host 0.0.0.0 --port 8000 --reload

  postgres:
    image: postgres:16
    environment:
      POSTGRES_DB: quiz_db
      POSTGRES_USER: quiz_user
      POSTGRES_PASSWORD: quiz_pass
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./scripts/init-db.sql:/docker-entrypoint-initdb.d/init-db.sql

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    command: redis-server --appendonly yes
    volumes:
      - redis_data:/data

  postgres-test:
    image: postgres:16
    environment:
      POSTGRES_DB: quiz_test_db
      POSTGRES_USER: quiz_user
      POSTGRES_PASSWORD: quiz_pass
    ports:
      - "5433:5432"
    profiles:
      - testing

volumes:
  postgres_data:
  redis_data:
EOF

# Database initialization script
echo "🗄️ Creating database initialization..."
cat > scripts/init-db.sql << 'EOF'
-- Create test database
CREATE DATABASE quiz_test_db;
GRANT ALL PRIVILEGES ON DATABASE quiz_test_db TO quiz_user;

-- Connect to main database and create extensions if needed
\c quiz_db;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Connect to test database and create extensions
\c quiz_test_db;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
EOF

# Test runner script
echo "🧪 Creating test runner..."
cat > scripts/run_tests.sh << 'EOF'
#!/bin/bash

set -e

echo "🧪 Running Quiz Service Tests..."

# Start test services
echo "🐳 Starting test database..."
docker-compose --profile testing up -d postgres-test redis

# Wait for services to be ready
echo "⏳ Waiting for services to be ready..."
sleep 10

# Run tests
echo "🚀 Running unit tests..."
python -m pytest src/tests/test_quiz_repository.py -v

echo "🚀 Running integration tests..."
python -m pytest src/tests/test_integration.py -v

# Cleanup
echo "🧹 Cleaning up test services..."
docker-compose --profile testing down

echo "✅ All tests completed!"
EOF

chmod +x scripts/run_tests.sh

# Performance test script
echo "📊 Creating performance tests..."
cat > scripts/performance_test.py << 'EOF'
import asyncio
import aiohttp
import time
import statistics
from concurrent.futures import ThreadPoolExecutor

async def create_quiz_request(session, quiz_data):
    """Make a single quiz creation request"""
    start_time = time.time()
    try:
        async with session.post('http://localhost:8000/quizzes/', json=quiz_data) as response:
            await response.json()
            return time.time() - start_time, response.status
    except Exception as e:
        return time.time() - start_time, 500

async def get_quiz_request(session, quiz_id):
    """Make a single quiz retrieval request"""
    start_time = time.time()
    try:
        async with session.get(f'http://localhost:8000/quizzes/{quiz_id}') as response:
            await response.json()
            return time.time() - start_time, response.status
    except Exception as e:
        return time.time() - start_time, 500

async def performance_test():
    """Run performance tests"""
    
    # Sample quiz data
    quiz_data = {
        "title": "Performance Test Quiz",
        "description": "Testing API performance",
        "category": "Performance",
        "difficulty": "medium",
        "questions": [
            {
                "question_text": "What is load testing?",
                "question_type": "multiple_choice",
                "points": 5,
                "order_index": 1,
                "answers": [
                    {"answer_text": "Testing individual components", "is_correct": False, "order_index": 1},
                    {"answer_text": "Testing system under load", "is_correct": True, "order_index": 2}
                ]
            }
        ]
    }
    
    print("🚀 Starting Performance Tests...")
    
    # Test concurrent quiz creation
    async with aiohttp.ClientSession() as session:
        print("📝 Testing Quiz Creation (100 concurrent requests)...")
        
        start_time = time.time()
        tasks = [create_quiz_request(session, quiz_data) for _ in range(100)]
        results = await asyncio.gather(*tasks)
        total_time = time.time() - start_time
        
        response_times = [r[0] for r in results]
        status_codes = [r[1] for r in results]
        
        successful_requests = sum(1 for code in status_codes if code == 201)
        
        print(f"✅ Quiz Creation Results:")
        print(f"   Total time: {total_time:.2f}s")
        print(f"   Successful requests: {successful_requests}/100")
        print(f"   Requests per second: {100/total_time:.2f}")
        print(f"   Average response time: {statistics.mean(response_times):.3f}s")
        print(f"   95th percentile: {statistics.quantiles(response_times, n=20)[18]:.3f}s")
        
        # Test concurrent quiz retrieval
        print("\n📖 Testing Quiz Retrieval (500 concurrent requests)...")
        
        start_time = time.time()
        # Use random quiz IDs from 1-10 (assuming some exist)
        tasks = [get_quiz_request(session, (i % 10) + 1) for i in range(500)]
        results = await asyncio.gather(*tasks)
        total_time = time.time() - start_time
        
        response_times = [r[0] for r in results]
        status_codes = [r[1] for r in results]
        
        successful_requests = sum(1 for code in status_codes if code in [200, 404])
        
        print(f"✅ Quiz Retrieval Results:")
        print(f"   Total time: {total_time:.2f}s")
        print(f"   Successful requests: {successful_requests}/500")
        print(f"   Requests per second: {500/total_time:.2f}")
        print(f"   Average response time: {statistics.mean(response_times):.3f}s")
        print(f"   95th percentile: {statistics.quantiles(response_times, n=20)[18]:.3f}s")

if __name__ == "__main__":
    asyncio.run(performance_test())
EOF

# Build and run script
echo "🔧 Creating build and run script..."
cat > scripts/build_and_run.sh << 'EOF'
#!/bin/bash

set -e

echo "🏗️ Building and Running Quiz Service..."

# Function to check if service is ready
wait_for_service() {
    local url=$1
    local service_name=$2
    local max_attempts=30
    local attempt=1