# 🧠 AI Quiz Platform - Authentication Service

A production-ready, containerized authentication microservice built with FastAPI, MongoDB, and JWT tokens. This service provides secure user registration, login, and session management for the AI Quiz Platform.

## 🚀 Quick Start (One-Click Deploy)

```bash
# Make the deployment script executable
chmod +x deploy.sh

# Deploy everything
./deploy.sh
```

**That's it!** The service will be available at http://localhost:8000

## 🏗️ Architecture Overview

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Frontend      │    │   Auth Service  │    │   MongoDB       │
│   (HTML/JS)     │◄──►│   (FastAPI)     │◄──►│   Database      │
│   Port 8000     │    │   Port 8000     │    │   Port 27017    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## 🔧 Manual Setup (Step by Step)

### Prerequisites
- Python 3.11+
- Docker & Docker Compose
- Git

### 1. Install Dependencies
```bash
pip install -r requirements.txt
```

### 2. Local Development
```bash
# Start MongoDB
docker run -d --name quiz-mongodb -p 27017:27017 mongo:7.0

# Run the service
python -m uvicorn src.main:app --reload --host 0.0.0.0 --port 8000
```

### 3. Container Deployment
```bash
# Build and start all services
docker-compose -f docker/docker-compose.yml up -d
```

## 🧪 Testing

### Run All Tests
```bash
python run_tests.py
```

### Run Specific Test Types
```bash
# Unit tests only
python run_tests.py unit

# Integration tests only
python run_tests.py integration

# API tests only
python run_tests.py api
```

### Expected Test Output
```
🎯 TEST SUMMARY
============================================================
✅ Successful: 15
❌ Failed: 0
📊 Success Rate: 100.0%
============================================================
🎉 ALL TESTS PASSED!
```

## 🔐 API Endpoints

### Public Endpoints
- `POST /auth/register` - User registration
- `POST /auth/login` - User login
- `GET /health` - Service health check
- `GET /auth/health` - Auth service health

### Protected Endpoints (Require JWT Token)
- `GET /auth/me` - Get current user info
- `POST /auth/logout` - User logout

### Example Usage

**Register a new user:**
```bash
curl -X POST "http://localhost:8000/auth/register" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "johndoe",
    "email": "john@example.com",
    "password": "SecurePass123!",
    "full_name": "John Doe"
  }'
```

**Login:**
```bash
curl -X POST "http://localhost:8000/auth/login" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "johndoe",
    "password": "SecurePass123!"
  }'
```

**Access protected endpoint:**
```bash
curl -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  "http://localhost:8000/auth/me"
```

## 🎯 Learning Objectives Achieved

By completing this lesson, you've built:

✅ **Secure Authentication System** - JWT-based with proper password hashing  
✅ **RESTful API** - Following best practices with FastAPI  
✅ **Database Integration** - MongoDB with proper schemas and validation  
✅ **Containerization** - Docker and Docker Compose setup  
✅ **Testing Suite** - Unit, integration, and API tests  
✅ **Frontend Interface** - Simple web UI for testing  
✅ **Production Ready** - Error handling, health checks, and monitoring  

## 🏆 Success Criteria

Your implementation is successful if:

1. ✅ All tests pass (100% success rate)
2. ✅ API documentation is accessible at `/docs`
3. ✅ Frontend interface works for registration/login
4. ✅ JWT tokens are properly generated and validated
5. ✅ Passwords are securely hashed with bcrypt
6. ✅ Services start successfully with Docker Compose
7. ✅ Health checks return "healthy" status

## 📚 Key Concepts Learned

### 1. Authentication vs Authorization
- **Authentication**: "Who are you?" (Login process)
- **Authorization**: "What can you do?" (Permissions)

### 2. JWT (JSON Web Tokens)
- Stateless authentication
- Self-contained tokens with user info
- Secure signature verification

### 3. Password Security
- Never store plain text passwords
- Use bcrypt for hashing
- Enforce strong password policies

### 4. API Design
- RESTful endpoints
- Proper HTTP status codes
- Consistent error handling

### 5. Containerization
- Docker for packaging applications
- Docker Compose for multi-service deployment
- Health checks and monitoring

## 🚨 Security Best Practices

1. **Strong Passwords**: Minimum 8 characters with uppercase, lowercase, numbers, and special characters
2. **Secure Hashing**: bcrypt with proper salt rounds
3. **JWT Security**: Secret key management and token expiration
4. **Input Validation**: Pydantic models for request validation
5. **HTTPS**: Always use HTTPS in production
6. **Environment Variables**: Keep secrets out of code

## 📊 System Monitoring

The service includes comprehensive monitoring:

- **Health Endpoints**: `/health` and `/auth/health`
- **Database Health**: MongoDB connection monitoring
- **Service Logs**: Structured logging with Docker
- **Metrics**: Request/response tracking

## 🔄 CI/CD Integration

This service is designed for easy integration with CI/CD pipelines:

```yaml
# Example GitHub Actions workflow
- name: Run Tests
  run: python run_tests.py

- name: Build Docker Image
  run: docker build -t quiz-auth .

- name: Deploy
  run: ./deploy.sh
```

## 🌐 Real-World Context

This authentication service follows patterns used by major platforms:

- **Netflix**: Microservices architecture with dedicated auth service
- **Uber**: JWT-based authentication for mobile and web apps
- **Discord**: Session management across multiple client types
- **GitHub**: API token authentication for developer tools

## 🎓 Assignment: Extend the Authentication Service

**Objective**: Add password reset functionality

**Requirements**:
1. Add `POST /auth/forgot-password` endpoint
2. Generate secure reset tokens
3. Add `POST /auth/reset-password` endpoint
4. Store reset tokens in database with expiration
5. Add appropriate tests

**Bonus**: Implement email verification for new accounts

## 💡 Next Steps

1. **Week 4**: Add role-based authorization (RBAC)
2. **Week 5**: Implement OAuth2 social login
3. **Week 6**: Add rate limiting and security headers
4. **Week 7**: Multi-factor authentication (MFA)

## 🤝 Contributing

This is a learning project! Feel free to:
- Add new features
- Improve security
- Optimize performance
- Write additional tests

---

**🎉 Congratulations!** You've built a production-ready authentication service that can handle thousands of users securely. This foundation will support all future features in the AI Quiz Platform!

For questions or issues, check the logs with `./deploy.sh logs` or run the test suite with `python run_tests.py`.
