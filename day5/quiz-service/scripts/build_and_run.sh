#!/bin/bash

set -e

echo "🏗️ Building and Running Quiz Service..."

# Function to check if service is ready
wait_for_service() {
    local url=$1
    local service_name=$2
    local max_attempts=30
    local attempt=1
    
    echo "Waiting for $service_name to be ready..."
    while [ $attempt -le $max_attempts ]; do
        if curl -s $url > /dev/null 2>&1; then
            echo "✅ $service_name is ready!"
            return 0
        fi
        echo "⏳ Attempt $attempt/$max_attempts - $service_name not ready yet..."
        sleep 2
        attempt=$((attempt + 1))
    done
    echo "❌ $service_name failed to start after $max_attempts attempts"
    return 1
}

# Function to check database connection
wait_for_postgres() {
    local max_attempts=30
    local attempt=1
    
    echo "Waiting for PostgreSQL to be ready..."
    while [ $attempt -le $max_attempts ]; do
        if docker-compose exec -T postgres pg_isready -U quiz_user -d quiz_db > /dev/null 2>&1; then
            echo "✅ PostgreSQL is ready!"
            return 0
        fi
        echo "⏳ Attempt $attempt/$max_attempts - PostgreSQL not ready yet..."
        sleep 2
        attempt=$((attempt + 1))
    done
    echo "❌ PostgreSQL failed to start after $max_attempts attempts"
    return 1
}

# Function to check Redis connection
wait_for_redis() {
    local max_attempts=30
    local attempt=1
    
    echo "Waiting for Redis to be ready..."
    while [ $attempt -le $max_attempts ]; do
        if docker-compose exec -T redis redis-cli ping > /dev/null 2>&1; then
            echo "✅ Redis is ready!"
            return 0
        fi
        echo "⏳ Attempt $attempt/$max_attempts - Redis not ready yet..."
        sleep 2
        attempt=$((attempt + 1))
    done
    echo "❌ Redis failed to start after $max_attempts attempts"
    return 1
}

# Stop any existing containers
echo "🧹 Cleaning up existing containers..."
docker-compose down --remove-orphans

# Build and start services
echo "🐳 Building Docker containers..."
docker-compose build

echo "🚀 Starting services..."
docker-compose up -d

# Wait for services to be ready
wait_for_postgres
wait_for_redis

# Wait a bit more for the API to fully initialize
echo "⏳ Waiting for API to initialize..."
sleep 10

# Check if API is responding
wait_for_service "http://localhost:8000/health" "Quiz API"

echo ""
echo "✅ All services are running!"
echo "================================"
echo ""
echo "🌐 Service URLs:"
echo "   API Documentation: http://localhost:8000/docs"
echo "   Health Check:      http://localhost:8000/health"
echo "   PostgreSQL:        localhost:5432"
echo "   Redis:             localhost:6379"
echo ""
echo "📋 Available API endpoints:"
echo "   POST   /quizzes/              - Create quiz"
echo "   GET    /quizzes/              - Get quizzes (with filters)"
echo "   GET    /quizzes/{id}          - Get specific quiz"
echo "   PUT    /quizzes/{id}          - Update quiz"
echo "   DELETE /quizzes/{id}          - Delete quiz"
echo "   GET    /quizzes/search/       - Search quizzes"
echo "   GET    /quizzes/stats/        - Get statistics"
echo "   GET    /health                - Health check"
echo ""
echo "🔧 Useful commands:"
echo "   View logs:        docker-compose logs -f"
echo "   Stop services:    docker-compose down"
echo "   Restart API:      docker-compose restart quiz-api"
echo "   Access DB:        docker-compose exec postgres psql -U quiz_user -d quiz_db"
echo "   Access Redis:     docker-compose exec redis redis-cli"
echo ""
echo "🌱 To add sample data:"
echo "   python scripts/seed_data.py"
echo ""
echo "🧪 To run tests:"
echo "   ./scripts/run_tests.sh"
echo ""
echo "📊 To run performance tests:"
echo "   python scripts/performance_test.py"