import pytest
import pytest_asyncio
from httpx import AsyncClient
from fastapi.testclient import TestClient
import asyncio

from src.main import app
from src.models.quiz import QuizCreate, QuestionCreate, AnswerCreate

@pytest.fixture
def sample_quiz_payload():
    return {
        "title": "Integration Test Quiz",
        "description": "Testing API endpoints",
        "category": "Testing",
        "difficulty": "medium",
        "questions": [
            {
                "question_text": "What is integration testing?",
                "question_type": "multiple_choice",
                "points": 5,
                "order_index": 1,
                "answers": [
                    {"answer_text": "Testing individual components", "is_correct": False, "order_index": 1},
                    {"answer_text": "Testing component interactions", "is_correct": True, "order_index": 2},
                    {"answer_text": "Testing user interface", "is_correct": False, "order_index": 3}
                ]
            }
        ]
    }

class TestQuizAPI:
    
    @pytest.mark.asyncio
    async def test_create_quiz_endpoint(self, sample_quiz_payload):
        """Test creating quiz via API"""
        async with AsyncClient(app=app, base_url="http://test") as client:
            response = await client.post("/quizzes/", json=sample_quiz_payload)
            
            assert response.status_code == 201
            data = response.json()
            assert data["title"] == "Integration Test Quiz"
            assert data["category"] == "Testing"
            assert len(data["questions"]) == 1
    
    @pytest.mark.asyncio
    async def test_get_quiz_endpoint(self, sample_quiz_payload):
        """Test getting quiz via API"""
        async with AsyncClient(app=app, base_url="http://test") as client:
            # Create quiz first
            create_response = await client.post("/quizzes/", json=sample_quiz_payload)
            created_quiz = create_response.json()
            quiz_id = created_quiz["id"]
            
            # Get quiz
            get_response = await client.get(f"/quizzes/{quiz_id}")
            
            assert get_response.status_code == 200
            data = get_response.json()
            assert data["id"] == quiz_id
            assert data["title"] == "Integration Test Quiz"
    
    @pytest.mark.asyncio
    async def test_get_quizzes_with_filters(self, sample_quiz_payload):
        """Test getting quizzes with filtering"""
        async with AsyncClient(app=app, base_url="http://test") as client:
            # Create multiple quizzes
            for i in range(3):
                quiz_data = sample_quiz_payload.copy()
                quiz_data["title"] = f"Test Quiz {i}"
                quiz_data["category"] = "Testing" if i < 2 else "Programming"
                await client.post("/quizzes/", json=quiz_data)
            
            # Test without filters
            response = await client.get("/quizzes/")
            assert response.status_code == 200
            data = response.json()
            assert len(data) == 3
            
            # Test with category filter
            response = await client.get("/quizzes/?category=Testing")
            assert response.status_code == 200
            data = response.json()
            assert len(data) == 2
            
            # Test with pagination
            response = await client.get("/quizzes/?skip=0&limit=2")
            assert response.status_code == 200
            data = response.json()
            assert len(data) == 2
    
    @pytest.mark.asyncio
    async def test_search_quizzes_endpoint(self, sample_quiz_payload):
        """Test searching quizzes"""
        async with AsyncClient(app=app, base_url="http://test") as client:
            # Create quiz
            await client.post("/quizzes/", json=sample_quiz_payload)
            
            # Search
            response = await client.get("/quizzes/search/?q=Integration")
            
            assert response.status_code == 200
            data = response.json()
            assert len(data) >= 1
            assert "Integration" in data[0]["title"]
    
    @pytest.mark.asyncio
    async def test_update_quiz_endpoint(self, sample_quiz_payload):
        """Test updating quiz via API"""
        async with AsyncClient(app=app, base_url="http://test") as client:
            # Create quiz
            create_response = await client.post("/quizzes/", json=sample_quiz_payload)
            quiz_id = create_response.json()["id"]
            
            # Update quiz
            update_data = {
                "title": "Updated Integration Test Quiz",
                "difficulty": "hard"
            }
            update_response = await client.put(f"/quizzes/{quiz_id}", json=update_data)
            
            assert update_response.status_code == 200
            data = update_response.json()
            assert data["title"] == "Updated Integration Test Quiz"
            assert data["difficulty"] == "hard"
    
    @pytest.mark.asyncio
    async def test_delete_quiz_endpoint(self, sample_quiz_payload):
        """Test deleting quiz via API"""
        async with AsyncClient(app=app, base_url="http://test") as client:
            # Create quiz
            create_response = await client.post("/quizzes/", json=sample_quiz_payload)
            quiz_id = create_response.json()["id"]
            
            # Delete quiz
            delete_response = await client.delete(f"/quizzes/{quiz_id}")
            
            assert delete_response.status_code == 200
            data = delete_response.json()
            assert data["success"] is True
    
    @pytest.mark.asyncio
    async def test_quiz_statistics_endpoint(self, sample_quiz_payload):
        """Test getting quiz statistics"""
        async with AsyncClient(app=app, base_url="http://test") as client:
            # Create a few quizzes
            for i in range(2):
                await client.post("/quizzes/", json=sample_quiz_payload)
            
            # Get statistics
            response = await client.get("/quizzes/stats/")
            
            assert response.status_code == 200
            data = response.json()
            assert "total_quizzes" in data
            assert data["total_quizzes"] >= 2
    
    @pytest.mark.asyncio
    async def test_health_check(self):
        """Test health check endpoint"""
        async with AsyncClient(app=app, base_url="http://test") as client:
            response = await client.get("/health")
            
            assert response.status_code == 200
            data = response.json()
            assert data["status"] == "healthy"

if __name__ == "__main__":
    pytest.main([__file__, "-v"])
