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
