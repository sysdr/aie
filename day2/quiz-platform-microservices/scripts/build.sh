# Complete Quiz Platform Build and Verification Process
# Follow these steps in order - each one builds on the previous

echo "🚀 Starting Quiz Platform Microservices Build Process"
echo "=================================================="

# Step 1: Install dependencies for all services
echo "📦 Installing dependencies for all services..."
cd services/user-service && npm install
cd ../quiz-service && npm install  
cd ../results-service && npm install
cd ../../

echo "✅ Dependencies installed successfully!"

# Step 2: Build Docker containers for all services
echo "🐳 Building Docker containers..."
docker-compose build --no-cache

echo "✅ All containers built successfully!"

# Step 3: Start the complete system
echo "🎬 Starting all microservices..."
docker-compose up -d

echo "⏱️  Waiting for services to initialize (30 seconds)..."
sleep 30

# Step 4: Verify all services are running
echo "🔍 Verifying service health..."

# Check User Service
echo "Checking User Service..."
curl -f http://localhost:3001/health || echo "❌ User Service failed"

# Check Quiz Service  
echo "Checking Quiz Service..."
curl -f http://localhost:3002/health || echo "❌ Quiz Service failed"

# Check Results Service
echo "Checking Results Service..."
curl -f http://localhost:3003/health || echo "❌ Results Service failed"

# Step 5: Test the complete workflow
echo "🧪 Testing complete quiz workflow..."

# Test user registration
echo "Testing user registration..."
curl -X POST http://localhost:3001/api/users/register \
  -H "Content-Type: application/json" \
  -d '{
    "username": "testuser",
    "email": "test@example.com", 
    "password": "password123"
  }'

# Test getting quizzes
echo "Testing quiz retrieval..."
curl -X GET http://localhost:3002/api/quizzes

# Test submitting results
echo "Testing result submission..."
curl -X POST http://localhost:3003/api/results/submit \
  -H "Content-Type: application/json" \
  -d '{
    "userId": 1,
    "quizId": 1,
    "answers": [0, 1],
    "timeSpent": 120
  }'

# Test leaderboard
echo "Testing leaderboard..."
curl -X GET http://localhost:3003/api/leaderboard

# Step 6: Display service information
echo ""
echo "🎉 SUCCESS! Your microservices are running!"
echo "=========================================="
echo ""
echo "Service Endpoints:"
echo "🔐 User Service:    http://localhost:3001"
echo "📝 Quiz Service:    http://localhost:3002" 
echo "🏆 Results Service: http://localhost:3003"
echo ""
echo "Health Checks:"
echo "💚 User Health:     http://localhost:3001/health"
echo "💚 Quiz Health:     http://localhost:3002/health"
echo "💚 Results Health:  http://localhost:3003/health"
echo ""
echo "Interactive Endpoints to Try:"
echo "👥 View Users:      http://localhost:3001/api/users"
echo "📚 View Quizzes:    http://localhost:3002/api/quizzes"
echo "🏅 View Leaderboard: http://localhost:3003/api/leaderboard"
echo ""

# Step 7: Show container status
echo "Container Status:"
docker-compose ps

echo ""
echo "🎯 Verification Complete!"
echo "Your distributed system is now running and ready for development!"

# Step 8: Instructions for stopping the system
echo ""
echo "To stop all services:"
echo "docker-compose down"
echo ""
echo "To stop and remove all data:"
echo "docker-compose down -v"