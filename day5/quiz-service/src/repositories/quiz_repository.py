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
