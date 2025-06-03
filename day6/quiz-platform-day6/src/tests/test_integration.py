import pytest
import json
from src.main import create_app

@pytest.fixture
def client():
    app = create_app()
    app.config['TESTING'] = True
    with app.test_client() as client:
        yield client

def test_health_check(client):
    """Test health endpoint"""
    response = client.get('/health')
    assert response.status_code == 200
    data = json.loads(response.data)
    assert data['status'] == 'healthy'

def test_create_quiz_endpoint(client):
    """Test quiz creation endpoint"""
    quiz_data = {
        "title": "Integration Test Quiz",
        "description": "Testing the API",
        "questions": [
            {
                "text": "What is testing?",
                "question_type": "multiple_choice",
                "difficulty": "easy",
                "options": ["Important", "Fun", "Both"],
                "correct_answer": "Both",
                "explanation": "Testing is both important and fun",
                "points": 1
            },
            {
                "text": "Integration tests check what?",
                "question_type": "short_answer",
                "difficulty": "medium",
                "correct_answer": "Component interactions",
                "explanation": "Integration tests verify components work together",
                "points": 2
            },
            {
                "text": "What is the hardest part of testing?",
                "question_type": "short_answer",
                "difficulty": "hard",
                "correct_answer": "Edge cases",
                "explanation": "Edge cases are often the most challenging",
                "points": 3
            }
        ],
        "time_limit": 600,
        "max_attempts": 2
    }
    
    response = client.post('/api/v1/quizzes/', 
                          data=json.dumps(quiz_data),
                          content_type='application/json')
    assert response.status_code == 201
    
    data = json.loads(response.data)
    assert data["title"] == "Integration Test Quiz"
    assert data["question_count"] == 3
    assert "easy" in data["difficulty_distribution"]

def test_validation_error_response(client):
    """Test validation error handling"""
    invalid_quiz = {
        "title": "Invalid Quiz",
        "questions": [
            {
                "text": "Only easy question here to test validation",
                "question_type": "true_false",
                "difficulty": "easy",
                "correct_answer": "True",
                "explanation": "Missing other difficulties in this quiz"
            }
        ]
    }
    
    response = client.post('/api/v1/quizzes/',
                          data=json.dumps(invalid_quiz),
                          content_type='application/json')
    assert response.status_code == 400
    
    data = json.loads(response.data)
    # The error could be from dataclass validation or business logic
    assert "Missing" in data["message"] or "Quiz must" in data["message"]

if __name__ == "__main__":
    pytest.main([__file__])
