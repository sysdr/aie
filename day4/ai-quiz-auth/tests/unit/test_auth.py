import pytest
from src.utils.password_utils import hash_password, verify_password, validate_password_strength
from src.utils.jwt_utils import create_access_token, verify_token
from src.models.user_model import UserCreate, UserLogin, TokenData

class TestPasswordUtils:
    def test_password_hashing(self):
        """Test password hashing and verification"""
        password = "TestPassword123!"
        hashed = hash_password(password)
        
        # Hash should be different from original
        assert hashed != password
        
        # Verification should work
        assert verify_password(password, hashed) is True
        assert verify_password("wrong_password", hashed) is False

    def test_password_strength_validation(self):
        """Test password strength validation"""
        # Strong password
        is_valid, msg = validate_password_strength("StrongPass123!")
        assert is_valid is True
        
        # Weak passwords
        weak_passwords = [
            "short",  # Too short
            "NoNumbersOrSpecial",  # No numbers or special chars
            "nonumbersorspecial123",  # No uppercase
            "NOLOWERCASEORSPECIAL123",  # No lowercase
            "NoSpecialChars123",  # No special characters
        ]
        
        for weak_pass in weak_passwords:
            is_valid, msg = validate_password_strength(weak_pass)
            assert is_valid is False
            assert msg  # Should have error message

class TestJWTUtils:
    def test_token_creation_and_verification(self):
        """Test JWT token creation and verification"""
        test_data = {"sub": "testuser", "user_id": "123"}
        token = create_access_token(test_data)
        
        # Token should be a string
        assert isinstance(token, str)
        assert len(token) > 0
        
        # Verify token
        token_data = verify_token(token)
        assert token_data is not None
        assert token_data.username == "testuser"
        assert token_data.user_id == "123"

    def test_invalid_token_verification(self):
        """Test verification of invalid tokens"""
        # Invalid token
        assert verify_token("invalid_token") is None
        
        # Empty token
        assert verify_token("") is None

class TestUserModels:
    def test_user_create_model(self):
        """Test UserCreate model validation"""
        # Valid user data
        user_data = {
            "username": "testuser",
            "email": "test@example.com",
            "password": "StrongPass123!",
            "full_name": "Test User"
        }
        user = UserCreate(**user_data)
        assert user.username == "testuser"
        assert user.email == "test@example.com"

    def test_user_login_model(self):
        """Test UserLogin model"""
        login_data = {
            "username": "testuser",
            "password": "password123"
        }
        login = UserLogin(**login_data)
        assert login.username == "testuser"
        assert login.password == "password123"

# Pytest configuration
if __name__ == "__main__":
    pytest.main([__file__])
