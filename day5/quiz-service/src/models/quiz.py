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
