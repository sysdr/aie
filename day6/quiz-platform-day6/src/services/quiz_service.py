from typing import List, Optional, Dict, Any
from datetime import datetime
import uuid
from collections import Counter

from src.models.quiz import Quiz, QuizCreateRequest, QuizResponse, DifficultyLevel, QuestionType
from src.repositories.quiz_repository import QuizRepository
from src.exceptions.quiz_exceptions import (
    ValidationError, QuizNotFoundError, UnauthorizedError, 
    QuizCreationLimitError, InvalidQuizStateError
)

class QuizService:
    def __init__(self, quiz_repository: QuizRepository, max_quizzes_per_user: int = 10):
        self.quiz_repository = quiz_repository
        self.max_quizzes_per_user = max_quizzes_per_user

    async def create_quiz(self, quiz_request: QuizCreateRequest, creator_id: str) -> QuizResponse:
        """Create a new quiz with business rule validation"""
        
        # Business Rule 1: Check user quota
        await self._validate_user_quota(creator_id)
        
        # Business Rule 2: Convert request to domain object (validates structure)
        quiz = quiz_request.to_quiz(creator_id)
        
        # Business Rule 3: Validate difficulty progression
        self._validate_difficulty_progression(quiz.questions)
        
        # Business Rule 4: Validate question type distribution
        self._validate_question_type_distribution(quiz.questions)
        
        # Persist quiz
        created_quiz = await self.quiz_repository.create(quiz)
        
        # Return response DTO
        return self._to_quiz_response(created_quiz)

    async def get_quiz(self, quiz_id: str, requester_id: str) -> QuizResponse:
        """Retrieve quiz with access control"""
        
        quiz = await self.quiz_repository.get_by_id(quiz_id)
        if not quiz:
            raise QuizNotFoundError(f"Quiz with ID {quiz_id} not found", "QUIZ_NOT_FOUND")
        
        # Business Rule: Access control
        if not self._can_access_quiz(quiz, requester_id):
            raise UnauthorizedError("Insufficient permissions to access quiz", "UNAUTHORIZED")
        
        return self._to_quiz_response(quiz)

    async def get_user_quizzes(self, creator_id: str, requester_id: str) -> List[QuizResponse]:
        """Get all quizzes for a user with access control"""
        
        # Business Rule: Users can only see their own quizzes unless admin
        if creator_id != requester_id and not self._is_admin(requester_id):
            raise UnauthorizedError("Cannot access other user's quizzes", "UNAUTHORIZED")
        
        quizzes = await self.quiz_repository.get_by_creator(creator_id)
        return [self._to_quiz_response(quiz) for quiz in quizzes]

    async def publish_quiz(self, quiz_id: str, publisher_id: str) -> QuizResponse:
        """Publish quiz with validation"""
        
        quiz = await self.quiz_repository.get_by_id(quiz_id)
        if not quiz:
            raise QuizNotFoundError(f"Quiz with ID {quiz_id} not found", "QUIZ_NOT_FOUND")
        
        # Business Rule: Only creator can publish
        if quiz.creator_id != publisher_id:
            raise UnauthorizedError("Only quiz creator can publish", "UNAUTHORIZED")
        
        # Business Rule: Validate quiz is ready for publishing
        self._validate_quiz_for_publishing(quiz)
        
        quiz.is_published = True
        quiz.updated_at = datetime.utcnow()
        
        updated_quiz = await self.quiz_repository.update(quiz)
        return self._to_quiz_response(updated_quiz)

    # Private validation methods
    async def _validate_user_quota(self, creator_id: str):
        """Validate user hasn't exceeded quiz creation quota"""
        quiz_count = await self.quiz_repository.get_creator_quiz_count(creator_id)
        if quiz_count >= self.max_quizzes_per_user:
            raise QuizCreationLimitError(
                f"User has reached maximum quiz limit ({self.max_quizzes_per_user})",
                "QUOTA_EXCEEDED"
            )

    def _validate_question_type_distribution(self, questions):
        """Validate question type distribution"""
        
        # Check question types distribution
        question_types = [q.question_type for q in questions]
        type_counts = Counter(question_types)
        
        # Business Rule: Maximum 80% of any single question type
        total_questions = len(questions)
        for question_type, count in type_counts.items():
            if count / total_questions > 0.8:
                raise ValidationError(
                    f"Too many {question_type.value} questions. Maximum 80% allowed.",
                    "QUESTION_TYPE_DISTRIBUTION_ERROR"
                )

    def _validate_difficulty_progression(self, questions):
        """Assignment challenge: Validate difficulty progression"""
        
        difficulties = [q.difficulty for q in questions]
        difficulty_counts = Counter(difficulties)
        
        # Rule 1: Must have at least one question of each difficulty
        required_difficulties = {DifficultyLevel.EASY, DifficultyLevel.MEDIUM, DifficultyLevel.HARD}
        missing_difficulties = required_difficulties - set(difficulties)
        
        if missing_difficulties:
            missing_str = ", ".join([d.value for d in missing_difficulties])
            raise ValidationError(
                f"Quiz must contain at least one question of each difficulty level. Missing: {missing_str}",
                "MISSING_DIFFICULTY_LEVELS"
            )
        
        # Rule 2: Questions should generally progress from easy to hard
        difficulty_scores = {
            DifficultyLevel.EASY: 1,
            DifficultyLevel.MEDIUM: 2,
            DifficultyLevel.HARD: 3
        }
        
        scores = [difficulty_scores[q.difficulty] for q in questions]
        
        # Check if progression is generally ascending (allow some variation)
        descending_pairs = sum(1 for i in range(len(scores)-1) if scores[i] > scores[i+1])
        max_allowed_descending = max(1, len(scores) // 2)  # Allow up to half to be out of order
        
        if descending_pairs > max_allowed_descending:
            raise ValidationError(
                "Questions should generally progress from easy to hard difficulty",
                "POOR_DIFFICULTY_PROGRESSION"
            )

    def _validate_quiz_for_publishing(self, quiz: Quiz):
        """Validate quiz is ready for publishing"""
        
        if len(quiz.questions) < 3:
            raise InvalidQuizStateError(
                "Quiz must have at least 3 questions to publish",
                "INSUFFICIENT_QUESTIONS"
            )
        
        # Check all questions have explanations (business rule for published quizzes)
        questions_without_explanations = [
            q for q in quiz.questions if not q.explanation or len(q.explanation.strip()) < 10
        ]
        
        if questions_without_explanations:
            raise InvalidQuizStateError(
                f"{len(questions_without_explanations)} questions missing explanations (minimum 10 characters)",
                "MISSING_EXPLANATIONS"
            )

    def _can_access_quiz(self, quiz: Quiz, requester_id: str) -> bool:
        """Check if user can access quiz"""
        # Published quizzes are accessible to all
        if quiz.is_published:
            return True
        
        # Draft quizzes only accessible by creator
        return quiz.creator_id == requester_id

    def _is_admin(self, user_id: str) -> bool:
        """Check if user is admin (simplified implementation)"""
        # In real implementation, this would check user roles
        return user_id.startswith("admin_")

    def _to_quiz_response(self, quiz: Quiz) -> QuizResponse:
        """Convert domain model to response DTO"""
        difficulty_distribution = Counter(q.difficulty.value for q in quiz.questions)
        
        return QuizResponse(
            id=quiz.id,
            title=quiz.title,
            description=quiz.description,
            creator_id=quiz.creator_id,
            question_count=len(quiz.questions),
            difficulty_distribution=dict(difficulty_distribution),
            time_limit=quiz.time_limit,
            max_attempts=quiz.max_attempts,
            is_published=quiz.is_published,
            created_at=quiz.created_at
        )
