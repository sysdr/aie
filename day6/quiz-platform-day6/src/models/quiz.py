from dataclasses import dataclass, field
from typing import List, Optional, Dict, Any
from enum import Enum
from datetime import datetime
import json

class DifficultyLevel(str, Enum):
    EASY = "easy"
    MEDIUM = "medium"
    HARD = "hard"

class QuestionType(str, Enum):
    MULTIPLE_CHOICE = "multiple_choice"
    TRUE_FALSE = "true_false"
    SHORT_ANSWER = "short_answer"

@dataclass
class Question:
    text: str
    question_type: QuestionType
    difficulty: DifficultyLevel
    correct_answer: str
    explanation: str
    options: Optional[List[str]] = None
    points: int = 1
    id: Optional[str] = None
    
    def __post_init__(self):
        # Validation logic
        if len(self.text) < 10 or len(self.text) > 500:
            raise ValueError("Question text must be 10-500 characters")
        if self.question_type == QuestionType.MULTIPLE_CHOICE and (not self.options or len(self.options) < 2):
            raise ValueError("Multiple choice questions must have at least 2 options")
        if not self.correct_answer or len(self.correct_answer) < 1:
            raise ValueError("Correct answer is required")
        if self.points < 1 or self.points > 10:
            raise ValueError("Points must be between 1 and 10")

@dataclass
class Quiz:
    title: str
    creator_id: str
    questions: List[Question]
    description: Optional[str] = None
    time_limit: Optional[int] = None
    max_attempts: int = 3
    is_published: bool = False
    id: Optional[str] = None
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None
    
    def __post_init__(self):
        # Validation logic
        if len(self.title) < 3 or len(self.title) > 200:
            raise ValueError("Title must be 3-200 characters")
        if self.description and len(self.description) > 1000:
            raise ValueError("Description cannot exceed 1000 characters")
        if len(self.questions) < 1 or len(self.questions) > 50:
            raise ValueError("Quiz must have 1-50 questions")
        if self.time_limit and (self.time_limit < 60 or self.time_limit > 7200):
            raise ValueError("Time limit must be 60-7200 seconds")
        if self.max_attempts < 1 or self.max_attempts > 10:
            raise ValueError("Max attempts must be 1-10")

@dataclass
class QuizCreateRequest:
    title: str
    questions: List[Dict[str, Any]]
    description: Optional[str] = None
    time_limit: Optional[int] = None
    max_attempts: int = 3
    
    def to_quiz(self, creator_id: str) -> Quiz:
        """Convert request to Quiz domain object"""
        question_objects = []
        for q_data in self.questions:
            question = Question(
                text=q_data['text'],
                question_type=QuestionType(q_data['question_type']),
                difficulty=DifficultyLevel(q_data['difficulty']),
                correct_answer=q_data['correct_answer'],
                explanation=q_data.get('explanation', ''),
                options=q_data.get('options'),
                points=q_data.get('points', 1)
            )
            question_objects.append(question)
        
        return Quiz(
            title=self.title,
            creator_id=creator_id,
            questions=question_objects,
            description=self.description,
            time_limit=self.time_limit,
            max_attempts=self.max_attempts,
            created_at=datetime.utcnow(),
            updated_at=datetime.utcnow()
        )

@dataclass
class QuizResponse:
    id: str
    title: str
    description: Optional[str]
    creator_id: str
    question_count: int
    difficulty_distribution: Dict[str, int]
    time_limit: Optional[int]
    max_attempts: int
    is_published: bool
    created_at: datetime
    
    def to_dict(self) -> dict:
        """Convert to dictionary for JSON serialization"""
        return {
            'id': self.id,
            'title': self.title,
            'description': self.description,
            'creator_id': self.creator_id,
            'question_count': self.question_count,
            'difficulty_distribution': self.difficulty_distribution,
            'time_limit': self.time_limit,
            'max_attempts': self.max_attempts,
            'is_published': self.is_published,
            'created_at': self.created_at.isoformat() if self.created_at else None
        }
