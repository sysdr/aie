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
