#!/bin/bash

echo "🛑 Stopping Quiz Platform Microservices..."

# Function to stop service
stop_service() {
    local service=$1
    if [ -f "logs/$service.pid" ]; then
        local pid=$(cat "logs/$service.pid")
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid"
            echo "Stopped $service (PID: $pid)"
        else
            echo "$service was not running"
        fi
        rm -f "logs/$service.pid"
    else
        echo "No PID file found for $service"
    fi
}

# Stop all services
stop_service "user-service"
stop_service "quiz-service"
stop_service "results-service"

echo "✅ All services stopped!"
