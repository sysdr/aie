from motor.motor_asyncio import AsyncIOMotorClient
from src.models.user_model import UserCreate, UserInDB, UserResponse, UserLogin
from src.utils.password_utils import hash_password, verify_password, validate_password_strength
from src.utils.jwt_utils import create_access_token, get_token_expiry
from datetime import datetime, timedelta
from typing import Optional
import os

class AuthService:
    def __init__(self):
        # MongoDB connection
        mongodb_url = os.getenv("MONGODB_URL", "mongodb://localhost:27017")
        self.client = AsyncIOMotorClient(mongodb_url)
        self.db = self.client.quiz_platform
        self.users_collection = self.db.users

    async def create_user(self, user_data: UserCreate) -> dict:
        """Create a new user"""
        # Validate password strength
        is_valid, message = validate_password_strength(user_data.password)
        if not is_valid:
            return {"success": False, "error": message}

        # Check if user already exists
        existing_user = await self.users_collection.find_one({
            "$or": [
                {"username": user_data.username},
                {"email": user_data.email}
            ]
        })
        
        if existing_user:
            field = "username" if existing_user["username"] == user_data.username else "email"
            return {"success": False, "error": f"User with this {field} already exists"}

        # Hash password and create user
        hashed_password = hash_password(user_data.password)
        user_dict = {
            "username": user_data.username,
            "email": user_data.email,
            "full_name": user_data.full_name,
            "hashed_password": hashed_password,
            "is_active": True,
            "created_at": datetime.utcnow(),
            "last_login": None
        }

        # Insert user into database
        result = await self.users_collection.insert_one(user_dict)
        user_dict["_id"] = result.inserted_id

        return {
            "success": True,
            "user": UserResponse(**user_dict).dict(),
            "message": "User created successfully"
        }

    async def authenticate_user(self, login_data: UserLogin) -> dict:
        """Authenticate user and return token"""
        # Find user by username
        user_doc = await self.users_collection.find_one({"username": login_data.username})
        
        if not user_doc:
            return {"success": False, "error": "Invalid username or password"}

        # Verify password
        if not verify_password(login_data.password, user_doc["hashed_password"]):
            return {"success": False, "error": "Invalid username or password"}

        # Check if user is active
        if not user_doc.get("is_active", True):
            return {"success": False, "error": "Account is deactivated"}

        # Update last login
        await self.users_collection.update_one(
            {"_id": user_doc["_id"]},
            {"$set": {"last_login": datetime.utcnow()}}
        )

        # Create access token
        token_data = {
            "sub": user_doc["username"],
            "user_id": str(user_doc["_id"])
        }
        access_token = create_access_token(token_data)

        return {
            "success": True,
            "access_token": access_token,
            "token_type": "bearer",
            "expires_in": get_token_expiry(),
            "user": UserResponse(**user_doc).dict()
        }

    async def get_user_by_username(self, username: str) -> Optional[UserInDB]:
        """Get user by username"""
        user_doc = await self.users_collection.find_one({"username": username})
        if user_doc:
            return UserInDB(**user_doc)
        return None

    async def get_user_by_id(self, user_id: str) -> Optional[UserResponse]:
        """Get user by ID"""
        try:
            from bson import ObjectId
            user_doc = await self.users_collection.find_one({"_id": ObjectId(user_id)})
            if user_doc:
                return UserResponse(**user_doc)
        except:
            pass
        return None

    async def update_user_activity(self, username: str):
        """Update user's last activity timestamp"""
        await self.users_collection.update_one(
            {"username": username},
            {"$set": {"last_activity": datetime.utcnow()}}
        )
