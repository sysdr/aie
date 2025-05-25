# Quiz Platform Microservices

A distributed quiz platform built with Node.js microservices architecture.

## Services
- **User Service** (Port 3001): Authentication and user management
- **Quiz Service** (Port 3002): Quiz content management
- **Results Service** (Port 3003): Score calculation and leaderboards

## Quick Start
```bash
# Start all services
./scripts/start-services.sh

# Run tests
./scripts/test-system.sh

# Stop services
./scripts/stop-services.sh
```

## API Endpoints
- User Service: http://localhost:3001/api/users
- Quiz Service: http://localhost:3002/api/quizzes  
- Results Service: http://localhost:3003/api/results
