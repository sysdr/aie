from abc import ABC, abstractmethod
from typing import List, Optional, Dict, Any
from src.models.quiz import Quiz

class QuizRepository(ABC):
    @abstractmethod
    async def create(self, quiz: Quiz) -> Quiz:
        pass

    @abstractmethod
    async def get_by_id(self, quiz_id: str) -> Optional[Quiz]:
        pass

    @abstractmethod
    async def get_by_creator(self, creator_id: str) -> List[Quiz]:
        pass

    @abstractmethod
    async def update(self, quiz: Quiz) -> Quiz:
        pass

    @abstractmethod
    async def delete(self, quiz_id: str) -> bool:
        pass

    @abstractmethod
    async def get_creator_quiz_count(self, creator_id: str) -> int:
        pass

# In-memory implementation for demo
class InMemoryQuizRepository(QuizRepository):
    def __init__(self):
        self._quizzes: Dict[str, Quiz] = {}
        self._next_id = 1

    async def create(self, quiz: Quiz) -> Quiz:
        quiz.id = str(self._next_id)
        self._next_id += 1
        self._quizzes[quiz.id] = quiz
        return quiz

    async def get_by_id(self, quiz_id: str) -> Optional[Quiz]:
        return self._quizzes.get(quiz_id)

    async def get_by_creator(self, creator_id: str) -> List[Quiz]:
        return [quiz for quiz in self._quizzes.values() if quiz.creator_id == creator_id]

    async def update(self, quiz: Quiz) -> Quiz:
        if quiz.id in self._quizzes:
            self._quizzes[quiz.id] = quiz
        return quiz

    async def delete(self, quiz_id: str) -> bool:
        if quiz_id in self._quizzes:
            del self._quizzes[quiz_id]
            return True
        return False

    async def get_creator_quiz_count(self, creator_id: str) -> int:
        return len([q for q in self._quizzes.values() if q.creator_id == creator_id])
