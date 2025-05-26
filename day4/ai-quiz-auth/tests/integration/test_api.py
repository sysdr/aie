import pytest
import asyncio
from httpx import AsyncClient
from src.main import app
import os

# Test configuration
TEST_USER = {
    "username": "testuser123",
    "email": "test@example.com",
    "password": "StrongPass123!",
    "full_name": "Test User"
}

@pytest.fixture
async def client():
    """Create test client"""
    async with AsyncClient(app=app, base_url="http://test") as ac:
        yield ac

@pytest.fixture
async def registered_user_token(client):
    """Create a registered user and return auth token"""
    # Register user
    response = await client.post("/auth/register", json=TEST_USER)
    assert response.status_code == 200
    
    # Login to get token
    login_data = {"username": TEST_USER["username"], "password": TEST_USER["password"]}
    response = await client.post("/auth/login", json=login_data)
    assert response.status_code == 200
    
    token_data = response.json()
    return token_data["access_token"]

class TestHealthEndpoints:
    @pytest.mark.asyncio
    async def test_main_health_check(self, client):
        """Test main health check endpoint"""
        response = await client.get("/health")
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "healthy"
        assert data["service"] == "ai-quiz-auth"

    @pytest.mark.asyncio
    async def test_auth_health_check(self, client):
        """Test auth service health check"""
        response = await client.get("/auth/health")
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "healthy"
        assert data["service"] == "auth-service"

class TestUserRegistration:
    @pytest.mark.asyncio
    async def test_successful_registration(self, client):
        """Test successful user registration"""
        user_data = {
            "username": f"testuser_{asyncio.current_task().get_name()}",
            "email": f"test_{asyncio.current_task().get_name()}@example.com",
            "password": "StrongPass123!",
            "full_name": "Test User"
        }
        
        response = await client.post("/auth/register", json=user_data)
        assert response.status_code == 200
        
        data = response.json()
        assert "message" in data
        assert "user" in data
        assert data["user"]["username"] == user_data["username"]
        assert data["user"]["email"] == user_data["email"]
        assert "hashed_password" not in data["user"]  # Should not expose password

    @pytest.mark.asyncio
    async def test_duplicate_user_registration(self, client):
        """Test registration with duplicate username/email"""
        # Register first user
        response = await client.post("/auth/register", json=TEST_USER)
        
        # Try to register again
        response = await client.post("/auth/register", json=TEST_USER)
        assert response.status_code == 400
        assert "already exists" in response.json()["detail"]

    @pytest.mark.asyncio
    async def test_weak_password_registration(self, client):
        """Test registration with weak password"""
        weak_user = TEST_USER.copy()
        weak_user["username"] = "weakpassuser"
        weak_user["password"] = "weak"
        
        response = await client.post("/auth/register", json=weak_user)
        assert response.status_code == 400
        assert "password" in response.json()["detail"].lower()

class TestUserLogin:
    @pytest.mark.asyncio
    async def test_successful_login(self, client):
        """Test successful user login"""
        # First register a user
        await client.post("/auth/register", json=TEST_USER)
        
        # Then login
        login_data = {"username": TEST_USER["username"], "password": TEST_USER["password"]}
        response = await client.post("/auth/login", json=login_data)
        
        assert response.status_code == 200
        data = response.json()
        assert "access_token" in data
        assert data["token_type"] == "bearer"
        assert "expires_in" in data

    @pytest.mark.asyncio
    async def test_invalid_login(self, client):
        """Test login with invalid credentials"""
        login_data = {"username": "nonexistent", "password": "wrongpassword"}
        response = await client.post("/auth/login", json=login_data)
        
        assert response.status_code == 401
        assert "Invalid username or password" in response.json()["detail"]

class TestProtectedEndpoints:
    @pytest.mark.asyncio
    async def test_get_current_user(self, client, registered_user_token):
        """Test getting current user info"""
        headers = {"Authorization": f"Bearer {registered_user_token}"}
        response = await client.get("/auth/me", headers=headers)
        
        assert response.status_code == 200
        data = response.json()
        assert data["username"] == TEST_USER["username"]
        assert data["email"] == TEST_USER["email"]

    @pytest.mark.asyncio
    async def test_protected_endpoint_without_token(self, client):
        """Test accessing protected endpoint without token"""
        response = await client.get("/auth/me")
        assert response.status_code == 403  # FastAPI HTTPBearer returns 403

    @pytest.mark.asyncio
    async def test_protected_endpoint_invalid_token(self, client):
        """Test accessing protected endpoint with invalid token"""
        headers = {"Authorization": "Bearer invalid_token"}
        response = await client.get("/auth/me", headers=headers)
        assert response.status_code == 401

    @pytest.mark.asyncio
    async def test_logout(self, client, registered_user_token):
        """Test user logout"""
        headers = {"Authorization": f"Bearer {registered_user_token}"}
        response = await client.post("/auth/logout", headers=headers)
        
        assert response.status_code == 200
        data = response.json()
        assert "message" in data
