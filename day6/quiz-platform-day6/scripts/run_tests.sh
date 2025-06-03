#!/bin/bash
echo "🧪 Running all tests..."

# Unit tests
echo "Running unit tests..."
python -m pytest src/tests/test_quiz_service.py -v

# Integration tests
echo "Running integration tests..."
python -m pytest src/tests/test_integration.py -v

echo "✅ All tests completed!"
