from dataclasses import dataclass, field
from datetime import datetime
from enum import Enum
from typing import Dict, Optional
import json

class AttemptStatus(Enum):
    STARTED = "started"
    IN_PROGRESS = "in_progress"
    COMPLETED = "completed"
    EXPIRED = "expired"
    ABANDONED = "abandoned"

@dataclass
class QuizAttempt:
    id: str
    user_id: str
    quiz_id: str
    started_at: datetime
    current_question: int = 0
    answers: Dict[int, str] = field(default_factory=dict)
    status: AttemptStatus = AttemptStatus.STARTED
    time_remaining: int = 1800  # 30 minutes in seconds
    last_updated: datetime = field(default_factory=datetime.utcnow)
    version: int = 1
    
    def to_dict(self) -> dict:
        return {
            'id': self.id,
            'user_id': self.user_id,
            'quiz_id': self.quiz_id,
            'started_at': self.started_at.isoformat(),
            'current_question': self.current_question,
            'answers': json.dumps(self.answers),
            'status': self.status.value,
            'time_remaining': self.time_remaining,
            'last_updated': self.last_updated.isoformat(),
            'version': self.version
        }
    
    @classmethod
    def from_dict(cls, data: dict) -> 'QuizAttempt':
        return cls(
            id=data['id'],
            user_id=data['user_id'],
            quiz_id=data['quiz_id'],
            started_at=datetime.fromisoformat(data['started_at']),
            current_question=data.get('current_question', 0),
            answers=json.loads(data.get('answers', '{}')),
            status=AttemptStatus(data.get('status', 'started')),
            time_remaining=data.get('time_remaining', 1800),
            last_updated=datetime.fromisoformat(data['last_updated']),
            version=data.get('version', 1)
        )
