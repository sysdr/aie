#!/bin/bash

set -e

echo "🧪 Running Quiz Service Tests..."

# Start test services
echo "🐳 Starting test database..."
docker-compose --profile testing up -d postgres-test redis

# Wait for services to be ready
echo "⏳ Waiting for services to be ready..."
sleep 10

# Run tests
echo "🚀 Running unit tests..."
python -m pytest src/tests/test_quiz_repository.py -v

echo "🚀 Running integration tests..."
python -m pytest src/tests/test_integration.py -v

# Cleanup
echo "🧹 Cleaning up test services..."
docker-compose --profile testing down

echo "✅ All tests completed!"
