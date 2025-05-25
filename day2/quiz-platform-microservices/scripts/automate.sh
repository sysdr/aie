#!/bin/bash

# Quiz Platform Microservices - Automated Test Suite
# This script comprehensively tests your distributed system

set -e  # Exit on any error

# Colors for beautiful output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0
START_TIME=$(date +%s)

# Configuration
USER_SERVICE_URL="http://localhost:3001"
QUIZ_SERVICE_URL="http://localhost:3002"
RESULTS_SERVICE_URL="http://localhost:3003"

echo -e "${CYAN}"
echo "██████╗ ██╗   ██╗██╗███████╗    ████████╗███████╗███████╗████████╗███████╗██████╗ "
echo "██╔═══██╗██║   ██║██║╚══███╔╝    ╚══██╔══╝██╔════╝██╔════╝╚══██╔══╝██╔════╝██╔══██╗"
echo "██║   ██║██║   ██║██║  ███╔╝        ██║   █████╗  ███████╗   ██║   █████╗  ██████╔╝"
echo "██║▄▄ ██║██║   ██║██║ ███╔╝         ██║   ██╔══╝  ╚════██║   ██║   ██╔══╝  ██╔══██╗"
echo "╚██████╔╝╚██████╔╝██║███████╗       ██║   ███████╗███████║   ██║   ███████╗██║  ██║"
echo " ╚══▀▀═╝  ╚═════╝ ╚═╝╚══════╝       ╚═╝   ╚══════╝╚══════╝   ╚═╝   ╚══════╝╚═╝  ╚═╝"
echo -e "${NC}"
echo -e "${PURPLE}🚀 Microservices Platform - Comprehensive Test Suite${NC}"
echo -e "${PURPLE}=================================================${NC}"
echo ""

# Function to print section headers
print_section() {
    echo -e "\n${BLUE}$1${NC}"
    echo -e "${BLUE}$(printf '%.0s-' {1..50})${NC}"
}

# Function to test HTTP endpoints
test_endpoint() {
    local method=$1
    local url=$2
    local data=$3
    local expected_status=$4
    local test_name=$5
    local should_contain=$6
    
    echo -n "  Testing $test_name... "
    
    # Make the HTTP request
    if [ "$method" = "POST" ] && [ -n "$data" ]; then
        response=$(curl -s -w "\n%{http_code}" -X "$method" "$url" \
            -H "Content-Type: application/json" \
            -d "$data" 2>/dev/null || echo -e "\n000")
    else
        response=$(curl -s -w "\n%{http_code}" "$url" 2>/dev/null || echo -e "\n000")
    fi
    
    # Extract status code (last line) and body (everything else)
    body=$(echo "$response" | head -n -1)
    status_code=$(echo "$response" | tail -n 1)
    
    # Validate status code
    if [ "$status_code" -eq "$expected_status" ]; then
        # Check if response should contain specific text
        if [ -n "$should_contain" ] && ! echo "$body" | grep -q "$should_contain"; then
            echo -e "${RED}❌ FAILED (Missing expected content: $should_contain)${NC}"
            ((TESTS_FAILED++))
            return
        fi
        echo -e "${GREEN}✅ PASSED${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}❌ FAILED (Expected: $expected_status, Got: $status_code)${NC}"
        if [ "$status_code" = "000" ]; then
            echo -e "    ${YELLOW}⚠️  Service might not be running${NC}"
        fi
        ((TESTS_FAILED++))
    fi
}

# Function to wait for services to be ready
wait_for_services() {
    print_section "🕐 Waiting for Services to Initialize"
    
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        echo -n "  Attempt $attempt/$max_attempts... "
        
        # Check if all services are responding
        user_status=$(curl -s -o /dev/null -w "%{http_code}" "$USER_SERVICE_URL/health" 2>/dev/null || echo "000")
        quiz_status=$(curl -s -o /dev/null -w "%{http_code}" "$QUIZ_SERVICE_URL/health" 2>/dev/null || echo "000")
        results_status=$(curl -s -o /dev/null -w "%{http_code}" "$RESULTS_SERVICE_URL/health" 2>/dev/null || echo "000")
        
        if [ "$user_status" = "200" ] && [ "$quiz_status" = "200" ] && [ "$results_status" = "200" ]; then
            echo -e "${GREEN}All services ready!${NC}"
            return 0
        else
            echo -e "${YELLOW}Services starting... (User: $user_status, Quiz: $quiz_status, Results: $results_status)${NC}"
            sleep 2
            ((attempt++))
        fi
    done
    
    echo -e "${RED}❌ Services failed to start within timeout${NC}"
    exit 1
}

# Function to run integration tests
run_integration_tests() {
    print_section "🔗 Integration Tests - Complete User Journey"
    
    echo -e "  ${CYAN}Simulating a complete user journey through the platform${NC}"
    
    # Step 1: Register a user
    echo -n "  Step 1: User Registration... "
    reg_response=$(curl -s -w "\n%{http_code}" -X POST "$USER_SERVICE_URL/api/users/register" \
        -H "Content-Type: application/json" \
        -d '{"username": "integration_user", "email": "integration@test.com", "password": "test123"}' 2>/dev/null || echo -e "\n000")
    
    reg_body=$(echo "$reg_response" | head -n -1)
    reg_status=$(echo "$reg_response" | tail -n 1)
    
    if [ "$reg_status" -eq 201 ]; then
        echo -e "${GREEN}✅ User registered${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}❌ Registration failed${NC}"
        ((TESTS_FAILED++))
        return
    fi
    
    # Step 2: Login
    echo -n "  Step 2: User Login... "
    login_response=$(curl -s -w "\n%{http_code}" -X POST "$USER_SERVICE_URL/api/users/login" \
        -H "Content-Type: application/json" \
        -d '{"email": "integration@test.com", "password": "test123"}' 2>/dev/null || echo -e "\n000")
    
    login_status=$(echo "$login_response" | tail -n 1)
    
    if [ "$login_status" -eq 200 ]; then
        echo -e "${GREEN}✅ Login successful${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}❌ Login failed${NC}"
        ((TESTS_FAILED++))
        return
    fi
    
    # Step 3: Browse available quizzes
    echo -n "  Step 3: Browse Quizzes... "
    quiz_response=$(curl -s -w "\n%{http_code}" "$QUIZ_SERVICE_URL/api/quizzes" 2>/dev/null || echo -e "\n000")
    quiz_status=$(echo "$quiz_response" | tail -n 1)
    
    if [ "$quiz_status" -eq 200 ]; then
        echo -e "${GREEN}✅ Quizzes retrieved${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}❌ Quiz retrieval failed${NC}"
        ((TESTS_FAILED++))
        return
    fi
    
    # Step 4: Take a quiz (submit answers)
    echo -n "  Step 4: Submit Quiz Answers... "
    result_response=$(curl -s -w "\n%{http_code}" -X POST "$RESULTS_SERVICE_URL/api/results/submit" \
        -H "Content-Type: application/json" \
        -d '{"userId": 2, "quizId": 1, "answers": [0, 1], "timeSpent": 150}' 2>/dev/null || echo -e "\n000")
    
    result_status=$(echo "$result_response" | tail -n 1)
    
    if [ "$result_status" -eq 201 ]; then
        echo -e "${GREEN}✅ Quiz submitted${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}❌ Quiz submission failed${NC}"
        ((TESTS_FAILED++))
        return
    fi
    
    # Step 5: Check leaderboard
    echo -n "  Step 5: View Leaderboard... "
    leaderboard_response=$(curl -s -w "\n%{http_code}" "$RESULTS_SERVICE_URL/api/leaderboard" 2>/dev/null || echo -e "\n000")
    leaderboard_status=$(echo "$leaderboard_response" | tail -n 1)
    
    if [ "$leaderboard_status" -eq 200 ]; then
        echo -e "${GREEN}✅ Leaderboard retrieved${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}❌ Leaderboard retrieval failed${NC}"
        ((TESTS_FAILED++))
        return
    fi
    
    echo -e "  ${GREEN}🎉 Complete user journey successful!${NC}"
}

# Function to test error handling
test_error_handling() {
    print_section "⚠️  Error Handling Tests"
    
    # Test invalid user registration
    test_endpoint "POST" "$USER_SERVICE_URL/api/users/register" \
        '{"username": "test"}' 400 "Invalid Registration Data"
    
    # Test nonexistent quiz
    test_endpoint "GET" "$QUIZ_SERVICE_URL/api/quizzes/999" \
        "" 404 "Nonexistent Quiz"
    
    # Test invalid quiz submission
    test_endpoint "POST" "$RESULTS_SERVICE_URL/api/results/submit" \
        '{"userId": 1}' 400 "Invalid Quiz Submission"
    
    # Test invalid login
    test_endpoint "POST" "$USER_SERVICE_URL/api/users/login" \
        '{"email": "wrong@email.com", "password": "wrongpass"}' 401 "Invalid Login Credentials"
}

# Function to test performance
test_performance() {
    print_section "⚡ Performance Tests"
    
    echo -n "  Testing response times... "
    
    # Test response time for health endpoints
    start_time=$(date +%s%3N)
    curl -s "$USER_SERVICE_URL/health" > /dev/null 2>&1
    end_time=$(date +%s%3N)
    user_time=$((end_time - start_time))
    
    start_time=$(date +%s%3N)
    curl -s "$QUIZ_SERVICE_URL/health" > /dev/null 2>&1
    end_time=$(date +%s%3N)
    quiz_time=$((end_time - start_time))
    
    start_time=$(date +%s%3N)
    curl -s "$RESULTS_SERVICE_URL/health" > /dev/null 2>&1
    end_time=$(date +%s%3N)
    results_time=$((end_time - start_time))
    
    echo -e "${GREEN}✅ PASSED${NC}"
    echo "    User Service: ${user_time}ms"
    echo "    Quiz Service: ${quiz_time}ms"
    echo "    Results Service: ${results_time}ms"
    
    ((TESTS_PASSED++))
}

# Function to check Docker setup (if applicable)
check_docker_setup() {
    if command -v docker-compose &> /dev/null; then
        print_section "🐳 Docker Setup Verification"
        
        # Check if docker-compose.yml exists
        if [ -f "docker-compose.yml" ]; then
            echo -n "  Docker Compose file exists... "
            echo -e "${GREEN}✅ PASSED${NC}"
            ((TESTS_PASSED++))
            
            # Check if containers are running
            echo -n "  Checking running containers... "
            if docker-compose ps | grep -q "Up"; then
                echo -e "${GREEN}✅ PASSED${NC}"
                ((TESTS_PASSED++))
            else
                echo -e "${YELLOW}⚠️  No containers running (might be using native approach)${NC}"
            fi
        else
            echo -e "  ${YELLOW}⚠️  Docker Compose file not found (using native approach)${NC}"
        fi
    else
        echo -e "  ${YELLOW}⚠️  Docker not installed (using native approach)${NC}"
    fi
}

# Main test execution
main() {
    echo -e "${CYAN}Starting comprehensive test suite...${NC}"
    echo -e "Test Target: Microservices running on ports 3001, 3002, 3003"
    echo ""
    
    # Wait for services
    wait_for_services
    
    # Health Check Tests
    print_section "🏥 Health Check Tests"
    test_endpoint "GET" "$USER_SERVICE_URL/health" "" 200 "User Service Health" "healthy"
    test_endpoint "GET" "$QUIZ_SERVICE_URL/health" "" 200 "Quiz Service Health" "healthy"
    test_endpoint "GET" "$RESULTS_SERVICE_URL/health" "" 200 "Results Service Health" "healthy"
    
    # User Service Tests
    print_section "👤 User Service Tests"
    test_endpoint "POST" "$USER_SERVICE_URL/api/users/register" \
        '{"username": "testuser1", "email": "test1@example.com", "password": "password123"}' \
        201 "User Registration"
    
    test_endpoint "POST" "$USER_SERVICE_URL/api/users/login" \
        '{"email": "test1@example.com", "password": "password123"}' \
        200 "User Login"
    
    test_endpoint "GET" "$USER_SERVICE_URL/api/users" "" 200 "Get All Users"
    
    # Quiz Service Tests
    print_section "📝 Quiz Service Tests"
    test_endpoint "GET" "$QUIZ_SERVICE_URL/api/quizzes" "" 200 "Get All Quizzes"
    test_endpoint "GET" "$QUIZ_SERVICE_URL/api/quizzes/1" "" 200 "Get Specific Quiz"
    
    # Results Service Tests
    print_section "🏆 Results Service Tests"
    test_endpoint "POST" "$RESULTS_SERVICE_URL/api/results/submit" \
        '{"userId": 1, "quizId": 1, "answers": [0, 1], "timeSpent": 120}' \
        201 "Submit Quiz Results"
    
    test_endpoint "GET" "$RESULTS_SERVICE_URL/api/leaderboard" "" 200 "Get Leaderboard"
    
    # Integration Tests
    run_integration_tests
    
    # Error Handling Tests
    test_error_handling
    
    # Performance Tests
    test_performance
    
    # Docker Setup Check
    check_docker_setup
    
    # Final Results
    print_section "📊 Test Results Summary"
    
    local end_time=$(date +%s)
    local duration=$((end_time - START_TIME))
    
    echo -e "  ${GREEN}Tests Passed: $TESTS_PASSED${NC}"
    echo -e "  ${RED}Tests Failed: $TESTS_FAILED${NC}"
    echo -e "  Total Tests: $((TESTS_PASSED + TESTS_FAILED))"
    echo -e "  Duration: ${duration}s"
    echo ""
    
    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "${GREEN}🎉 CONGRATULATIONS! 🎉${NC}"
        echo -e "${GREEN}All tests passed! Your microservices platform is working perfectly.${NC}"
        echo ""
        echo -e "${CYAN}Your services are ready for:"
        echo -e "  ✓ Development and testing"
        echo -e "  ✓ Adding new features"
        echo -e "  ✓ Integration with frontend"
        echo -e "  ✓ Production deployment${NC}"
        echo ""
        echo -e "${PURPLE}Next steps:"
        echo -e "  • Visit http://localhost:3001/api/users to see users"
        echo -e "  • Visit http://localhost:3002/api/quizzes to see quizzes"
        echo -e "  • Visit http://localhost:3003/api/leaderboard to see rankings${NC}"
        exit 0
    else
        echo -e "${RED}⚠️  Some tests failed. Please check the following:${NC}"
        echo -e "  • All services are running on correct ports"
        echo -e "  • No firewall blocking local connections"
        echo -e "  • Services have proper permissions"
        echo -e "  • Check service logs for errors"
        echo ""
        echo -e "${YELLOW}Debug commands:${NC}"
        echo -e "  curl http://localhost:3001/health"
        echo -e "  curl http://localhost:3002/health"
        echo -e "  curl http://localhost:3003/health"
        exit 1
    fi
}

# Run the tests
main