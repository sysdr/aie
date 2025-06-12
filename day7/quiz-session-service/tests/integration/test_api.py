import pytest
import httpx
import asyncio
from fastapi.testclient import TestClient
import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '../../src'))
from main import app

@pytest.fixture
def client():
    return TestClient(app)

def test_health_check(client):
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json()["status"] == "healthy"

@pytest.mark.asyncio
async def test_session_lifecycle():
    async with httpx.AsyncClient(app=app, base_url="http://test") as client:
        # Create session
        create_response = await client.post(
            "/api/v1/sessions/",
            json={"user_id": "test_user", "quiz_id": "test_quiz"}
        )
        assert create_response.status_code == 200
        session_data = create_response.json()
        session_id = session_data["id"]
        
        # Get session
        get_response = await client.get(f"/api/v1/sessions/{session_id}")
        assert get_response.status_code == 200
        
        # Update progress
        progress_response = await client.put(
            f"/api/v1/sessions/{session_id}/progress",
            json={"question_id": 1, "answer": "A"}
        )
        assert progress_response.status_code == 200
        
        # Complete session
        complete_response = await client.post(f"/api/v1/sessions/{session_id}/complete")
        assert complete_response.status_code == 200

def test_session_not_found(client):
    response = client.get("/api/v1/sessions/nonexistent")
    assert response.status_code == 404
