#!/bin/bash

echo "🚀 Starting Quiz Platform Microservices..."

# Function to start service in background
start_service() {
    local service=$1
    local port=$2
    echo "Starting $service on port $port..."
    cd "services/$service"
    nohup npm start > "../../logs/$service.log" 2>&1 &
    echo $! > "../../logs/$service.pid"
    cd ../../
}

# Create logs directory
mkdir -p logs

# Start all services
start_service "user-service" "3001"
start_service "quiz-service" "3002"  
start_service "results-service" "3003"

echo "✅ All services started!"
echo "📋 Check logs in ./logs/ directory"
echo "🧪 Run ./scripts/test-system.sh to verify"
