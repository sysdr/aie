#!/bin/bash

# AI Quiz Platform - Authentication Service Deployment Script
# This script handles the complete deployment process

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_NAME="ai-quiz-auth"
DOCKER_COMPOSE_FILE="docker/docker-compose.yml"
HEALTH_CHECK_URL="http://localhost:8000/health"
MAX_HEALTH_RETRIES=30

# Functions
print_header() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

check_dependencies() {
    print_header "Checking Dependencies"
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    print_success "Docker is available"
    
    # Check Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        print_error "Docker Compose is not installed. Please install Docker Compose first."
        exit 1
    fi
    print_success "Docker Compose is available"
    
    # Check Python
    if ! command -v python3 &> /dev/null; then
        print_error "Python 3 is not installed. Please install Python 3 first."
        exit 1
    fi
    print_success "Python 3 is available"
}

cleanup_existing() {
    print_header "Cleaning Up Existing Deployment"
    
    # Stop and remove existing containers
    if docker-compose -f $DOCKER_COMPOSE_FILE ps -q | grep -q .; then
        print_info "Stopping existing containers..."
        docker-compose -f $DOCKER_COMPOSE_FILE down
        print_success "Existing containers stopped"
    else
        print_info "No existing containers found"
    fi
    
    # Remove unused Docker resources
    print_info "Cleaning up Docker resources..."
    docker system prune -f
    print_success "Docker cleanup completed"
}

build_and_deploy() {
    print_header "Building and Deploying Services"
    
    # Build and start services
    print_info "Building Docker images..."
    docker-compose -f $DOCKER_COMPOSE_FILE build --no-cache
    print_success "Docker images built successfully"
    
    print_info "Starting services..."
    docker-compose -f $DOCKER_COMPOSE_FILE up -d
    print_success "Services started successfully"
}

wait_for_services() {
    print_header "Waiting for Services to be Ready"
    
    local retry_count=0
    while [ $retry_count -lt $MAX_HEALTH_RETRIES ]; do
        if curl -s $HEALTH_CHECK_URL > /dev/null 2>&1; then
            print_success "All services are healthy and ready!"
            return 0
        fi
        
        retry_count=$((retry_count + 1))
        print_info "Waiting for services... ($retry_count/$MAX_HEALTH_RETRIES)"
        sleep 2
    done
    
    print_error "Services failed to become healthy within timeout"
    return 1
}

run_health_checks() {
    print_header "Running Health Checks"
    
    # Main service health
    if curl -s $HEALTH_CHECK_URL | grep -q "healthy"; then
        print_success "Main service health check passed"
    else
        print_error "Main service health check failed"
        return 1
    fi
    
    # Auth service health
    if curl -s "http://localhost:8000/auth/health" | grep -q "healthy"; then
        print_success "Auth service health check passed"
    else
        print_error "Auth service health check failed"
        return 1
    fi
    
    # Database connectivity test
    if docker-compose -f $DOCKER_COMPOSE_FILE exec -T mongodb mongosh --eval "db.adminCommand('ping')" quiz_platform > /dev/null 2>&1; then
        print_success "Database connectivity check passed"
    else
        print_error "Database connectivity check failed"
        return 1
    fi
}

run_smoke_tests() {
    print_header "Running Smoke Tests"
    
    # Test user registration
    local test_user='{"username":"smoketest","email":"smoke@test.com","password":"TestPass123!","full_name":"Smoke Test"}'
    
    if curl -s -X POST "http://localhost:8000/auth/register" \
        -H "Content-Type: application/json" \
        -d "$test_user" | grep -q "User created successfully"; then
        print_success "User registration smoke test passed"
        
        # Test login
        local login_data='{"username":"smoketest","password":"TestPass123!"}'
        local token_response=$(curl -s -X POST "http://localhost:8000/auth/login" \
            -H "Content-Type: application/json" \
            -d "$login_data")
        
        if echo "$token_response" | grep -q "access_token"; then
            print_success "User login smoke test passed"
            
            # Extract token and test protected endpoint
            local token=$(echo "$token_response" | python3 -c "import sys, json; print(json.load(sys.stdin)['access_token'])")
            
            if curl -s -H "Authorization: Bearer $token" "http://localhost:8000/auth/me" | grep -q "smoketest"; then
                print_success "Protected endpoint smoke test passed"
            else
                print_error "Protected endpoint smoke test failed"
                return 1
            fi
        else
            print_error "User login smoke test failed"
            return 1
        fi
    else
        print_error "User registration smoke test failed"
        return 1
    fi
}

show_deployment_info() {
    print_header "Deployment Information"
    
    echo -e "${GREEN}🎉 Deployment completed successfully!${NC}"
    echo ""
    echo -e "${BLUE}Service URLs:${NC}"
    echo -e "  🌐 Web Interface: http://localhost:8000"
    echo -e "  📚 API Documentation: http://localhost:8000/docs"
    echo -e "  ❤️  Health Check: http://localhost:8000/health"
    echo -e "  🔐 Auth Health: http://localhost:8000/auth/health"
    echo ""
    echo -e "${BLUE}Quick Commands:${NC}"
    echo -e "  View logs: docker-compose -f $DOCKER_COMPOSE_FILE logs -f"
    echo -e "  Stop services: docker-compose -f $DOCKER_COMPOSE_FILE down"
    echo -e "  Run tests: python run_tests.py"
    echo ""
    echo -e "${BLUE}Database Access:${NC}"
    echo -e "  MongoDB: mongodb://admin:password123@localhost:27017/quiz_platform"
    echo -e "  Connect: docker-compose -f $DOCKER_COMPOSE_FILE exec mongodb mongosh quiz_platform"
}

show_logs() {
    print_header "Service Logs"
    docker-compose -f $DOCKER_COMPOSE_FILE logs --tail=20
}

# Main deployment function
deploy() {
    print_header "🚀 AI Quiz Platform - Authentication Service Deployment"
    
    # Run deployment steps
    check_dependencies
    cleanup_existing
    build_and_deploy
    
    if wait_for_services; then
        if run_health_checks && run_smoke_tests; then
            show_deployment_info
            return 0
        else
            print_error "Health checks or smoke tests failed"
            show_logs
            return 1
        fi
    else
        print_error "Services failed to start properly"
        show_logs
        return 1
    fi
}

# Command line argument handling
case "${1:-deploy}" in
    "deploy")
        deploy
        ;;
    "stop")
        print_header "Stopping Services"
        docker-compose -f $DOCKER_COMPOSE_FILE down
        print_success "Services stopped"
        ;;
    "restart")
        print_header "Restarting Services"
        docker-compose -f $DOCKER_COMPOSE_FILE restart
        wait_for_services
        print_success "Services restarted"
        ;;
    "logs")
        show_logs
        ;;
    "status")
        print_header "Service Status"
        docker-compose -f $DOCKER_COMPOSE_FILE ps
        ;;
    "clean")
        print_header "Deep Clean"
        docker-compose -f $DOCKER_COMPOSE_FILE down -v
        docker system prune -af
        print_success "Deep clean completed"
        ;;
    "test")
        print_header "Running Tests"
        python run_tests.py
        ;;
    *)
        echo "Usage: $0 {deploy|stop|restart|logs|status|clean|test}"
        echo ""
        echo "Commands:"
        echo "  deploy  - Full deployment (default)"
        echo "  stop    - Stop all services"
        echo "  restart - Restart all services"
        echo "  logs    - Show service logs"
        echo "  status  - Show service status"
        echo "  clean   - Deep clean (removes all data)"
        echo "  test    - Run test suite"
        exit 1
        ;;
esac
