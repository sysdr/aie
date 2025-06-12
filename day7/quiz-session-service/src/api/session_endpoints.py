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
