import pytest
import asyncio
from src.services.quiz_service import QuizService
from src.repositories.quiz_repository import InMemoryQuizRepository
from src.models.quiz import QuizCreateRequest, Question, DifficultyLevel, QuestionType
from src.exceptions.quiz_exceptions import ValidationError, QuizCreationLimitError

@pytest.fixture
def quiz_service():
    repository = InMemoryQuizRepository()
    return QuizService(repository, max_quizzes_per_user=2)

@pytest.fixture
def valid_quiz_request():
    questions = [
        {
            "text": "What is 2+2?",
            "question_type": "multiple_choice",
            "difficulty": "easy",
            "options": ["3", "4", "5"],
            "correct_answer": "4",
            "explanation": "Basic arithmetic",
            "points": 1
        },
        {
            "text": "What is the capital of France?",
            "question_type": "multiple_choice",
            "difficulty": "medium", 
            "options": ["London", "Paris", "Berlin"],
            "correct_answer": "Paris",
            "explanation": "France's capital city",
            "points": 2
        },
        {
            "text": "Explain quantum mechanics",
            "question_type": "short_answer",
            "difficulty": "hard",
            "correct_answer": "Complex physics theory",
            "explanation": "Advanced physics concept",
            "points": 5
        }
    ]
    
    return QuizCreateRequest(
        title="Test Quiz",
        description="A test quiz",
        questions=questions,
        time_limit=300,
        max_attempts=3
    )

@pytest.mark.asyncio
async def test_create_quiz_success(quiz_service, valid_quiz_request):
    """Test successful quiz creation"""
    result = await quiz_service.create_quiz(valid_quiz_request, "user_123")
    
    assert result.title == "Test Quiz"
    assert result.question_count == 3
    assert result.creator_id == "user_123"
    assert "easy" in result.difficulty_distribution
    assert "medium" in result.difficulty_distribution
    assert "hard" in result.difficulty_distribution

@pytest.mark.asyncio
async def test_create_quiz_quota_exceeded(quiz_service, valid_quiz_request):
    """Test quiz creation quota enforcement"""
    # Create maximum allowed quizzes
    await quiz_service.create_quiz(valid_quiz_request, "user_123")
    await quiz_service.create_quiz(valid_quiz_request, "user_123")
    
    # Third quiz should fail
    with pytest.raises(QuizCreationLimitError):
        await quiz_service.create_quiz(valid_quiz_request, "user_123")

@pytest.mark.asyncio
async def test_difficulty_progression_validation(quiz_service):
    """Test difficulty progression business rule"""
    # Missing hard difficulty
    questions = [
        {
            "text": "Easy question",
            "question_type": "true_false",
            "difficulty": "easy",
            "correct_answer": "True",
            "explanation": "Easy explanation"
        },
        {
            "text": "Medium question",
            "question_type": "true_false",
            "difficulty": "medium",
            "correct_answer": "False",
            "explanation": "Medium explanation"
        }
    ]
    
    quiz_request = QuizCreateRequest(
        title="Invalid Quiz",
        questions=questions
    )
    
    with pytest.raises(ValidationError) as exc_info:
        await quiz_service.create_quiz(quiz_request, "user_123")
    
    assert "Missing: hard" in str(exc_info.value)

@pytest.mark.asyncio
async def test_question_type_distribution(quiz_service):
    """Test question type distribution validation"""
    # All questions are same type (over 80%)
    questions = [
        {
            "text": f"Question {i}",
            "question_type": "true_false",
            "difficulty": "easy" if i < 2 else "medium" if i < 4 else "hard",
            "correct_answer": "True",
            "explanation": "Explanation"
        } for i in range(6)
    ]
    
    quiz_request = QuizCreateRequest(
        title="Invalid Distribution Quiz",
        questions=questions
    )
    
    with pytest.raises(ValidationError) as exc_info:
        await quiz_service.create_quiz(quiz_request, "user_123")
    
    assert "Too many true_false questions" in str(exc_info.value)

if __name__ == "__main__":
    pytest.main([__file__])
