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
