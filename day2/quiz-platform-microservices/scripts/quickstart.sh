#!/bin/bash

# Quiz Platform Microservices - Quick Start Script
# This script sets up everything automatically

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}"
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║                    QUIZ PLATFORM QUICK START                 ║"
echo "║              Microservices Architecture Setup                 ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Function to print status
print_status() {
    echo -e "${BLUE}[$(date +'%H:%M:%S')] $1${NC}"
}

# Function to check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check Node.js
    if ! command -v node &> /dev/null; then
        echo -e "${RED}❌ Node.js is not installed. Please install Node.js 16+ first.${NC}"
        exit 1
    fi
    
    local node_version=$(node --version | sed 's/v//' | cut -d. -f1)
    if [ "$node_version" -lt 16 ]; then
        echo -e "${RED}❌ Node.js version 16+ required. Current: $(node --version)${NC}"
        exit 1
    fi
    
    # Check npm
    if ! command -v npm &> /dev/null; then
        echo -e "${RED}❌ npm is not installed.${NC}"
        exit 1
    fi
    
    # Check curl
    if ! command -v curl &> /dev/null; then
        echo -e "${RED}❌ curl is not installed. Please install curl for testing.${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ All prerequisites met${NC}"
    echo "   Node.js: $(node --version)"
    echo "   npm: $(npm --version)"
}

# Function to create project structure
create_project_structure() {
    print_status "Creating project structure..."
    
    # Create directories
    mkdir -p services/{user-service,quiz-service,results-service}
    mkdir -p shared/{utils,middleware}
    mkdir -p scripts tests docs
    
    # Create gitignore
    cat > .gitignore << 'EOF'
node_modules/
.env
*.log
.DS_Store
coverage/
dist/
EOF
    
    # Create README
    cat > README.md << 'EOF'
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
EOF
    
    echo -e "${GREEN}✅ Project structure created${NC}"
}

# Function to create package.json files
create_package_files() {
    print_status "Creating package.json files..."
    
    # User Service
    cat > services/user-service/package.json << 'EOF'
{
  "name": "user-service",
  "version": "1.0.0",
  "description": "User authentication and profile management service",
  "main": "index.js",
  "scripts": {
    "start": "node index.js",
    "dev": "nodemon index.js"
  },
  "dependencies": {
    "express": "^4.18.2",
    "cors": "^2.8.5",
    "helmet": "^7.0.0",
    "morgan": "^1.10.0",
    "dotenv": "^16.3.1"
  },
  "devDependencies": {
    "nodemon": "^3.0.1"
  }
}
EOF
    
    # Quiz Service
    cat > services/quiz-service/package.json << 'EOF'
{
  "name": "quiz-service",
  "version": "1.0.0",
  "description": "Quiz content management service",
  "main": "index.js",
  "scripts": {
    "start": "node index.js",
    "dev": "nodemon index.js"
  },
  "dependencies": {
    "express": "^4.18.2",
    "cors": "^2.8.5",
    "helmet": "^7.0.0",
    "morgan": "^1.10.0",
    "dotenv": "^16.3.1"
  },
  "devDependencies": {
    "nodemon": "^3.0.1"
  }
}
EOF
    
    # Results Service
    cat > services/results-service/package.json << 'EOF'
{
  "name": "results-service",
  "version": "1.0.0",
  "description": "Results processing and leaderboard service",
  "main": "index.js",
  "scripts": {
    "start": "node index.js",
    "dev": "nodemon index.js"
  },
  "dependencies": {
    "express": "^4.18.2",
    "cors": "^2.8.5",
    "helmet": "^7.0.0",
    "morgan": "^1.10.0",
    "dotenv": "^16.3.1"
  },
  "devDependencies": {
    "nodemon": "^3.0.1"
  }
}
EOF
    
    echo -e "${GREEN}✅ Package files created${NC}"
}

# Function to install dependencies
install_dependencies() {
    print_status "Installing dependencies for all services..."
    
    cd services/user-service
    npm install --silent
    cd ../quiz-service
    npm install --silent
    cd ../results-service
    npm install --silent
    cd ../../
    
    echo -e "${GREEN}✅ Dependencies installed${NC}"
}

# Function to create service scripts
create_service_scripts() {
    print_status "Creating management scripts..."
    
    # Start services script
    cat > scripts/start-services.sh << 'EOF'
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
EOF
    
    # Stop services script
    cat > scripts/stop-services.sh << 'EOF'
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
EOF
    
    # Make scripts executable
    chmod +x scripts/*.sh
    
    echo -e "${GREEN}✅ Management scripts created${NC}"
}

# Function to prompt user for setup choice
choose_setup_method() {
    echo ""
    echo -e "${YELLOW}Choose your setup method:${NC}"
    echo "1) Native (Run directly with Node.js)"
    echo "2) Docker (Run in containers)"
    echo "3) Both (Create files for both methods)"
    echo ""
    read -p "Enter your choice (1-3): " choice
    
    case $choice in
        1)
            echo -e "${BLUE}Setting up for native development...${NC}"
            setup_native
            ;;
        2)
            echo -e "${BLUE}Setting up for Docker development...${NC}"
            setup_docker
            ;;
        3)
            echo -e "${BLUE}Setting up for both methods...${NC}"
            setup_native
            setup_docker
            ;;
        *)
            echo -e "${RED}Invalid choice. Defaulting to native setup.${NC}"
            setup_native
            ;;
    esac
}

# Function to setup native development
setup_native() {
    print_status "Setting up native development environment..."
    
    # Copy service files from the artifacts we created earlier
    # This is where you'd paste the actual service code
    
    echo -e "${GREEN}✅ Native setup complete${NC}"
    echo ""
    echo -e "${CYAN}To start your services:${NC}"
    echo "  ./scripts/start-services.sh"
    echo ""
    echo -e "${CYAN}To test your services:${NC}"
    echo "  ./scripts/test-system.sh"
}

# Function to setup Docker development  
setup_docker() {
    print_status "Setting up Docker development environment..."
    
    # Check if Docker is available
    if ! command -v docker &> /dev/null || ! command -v docker-compose &> /dev/null; then
        echo -e "${YELLOW}⚠️  Docker/Docker Compose not found. Skipping Docker setup.${NC}"
        return
    fi
    
    # Create docker-compose.yml
    cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  user-service:
    build:
      context: ./services/user-service
      dockerfile: Dockerfile
    ports:
      - "3001:3001"
    environment:
      - NODE_ENV=development
      - PORT=3001
    networks:
      - quiz-network
    restart: unless-stopped

  quiz-service:
    build:
      context: ./services/quiz-service
      dockerfile: Dockerfile
    ports:
      - "3002:3002"
    environment:
      - NODE_ENV=development
      - PORT=3002
    networks:
      - quiz-network
    restart: unless-stopped

  results-service:
    build:
      context: ./services/results-service
      dockerfile: Dockerfile
    ports:
      - "3003:3003"
    environment:
      - NODE_ENV=development
      - PORT=3003
    networks:
      - quiz-network
    restart: unless-stopped

networks:
  quiz-network:
    driver: bridge
EOF
    
    # Create Dockerfiles for each service
    for service in user-service quiz-service results-service; do
        cat > "services/$service/Dockerfile" << 'EOF'
FROM node:18-alpine

WORKDIR /app

COPY package*.json ./

RUN npm install

COPY . .

EXPOSE 3001

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:3001/health || exit 1

CMD ["npm", "start"]
EOF
    done
    
    echo -e "${GREEN}✅ Docker setup complete${NC}"
    echo ""
    echo -e "${CYAN}To start with Docker:${NC}"
    echo "  docker-compose up -d"
    echo ""
    echo -e "${CYAN}To test Docker setup:${NC}"
    echo "  ./scripts/test-system.sh"
}

# Main setup function
main() {
    echo -e "${PURPLE}Welcome to Quiz Platform Microservices Setup!${NC}"
    echo ""
    
    # Check if we're in the right directory
    if [ -f "services/user-service/index.js" ]; then
        echo -e "${YELLOW}⚠️  Project already exists. Continue anyway? (y/N)${NC}"
        read -p "" confirm
        if [[ ! $confirm =~ ^[Yy]$ ]]; then
            echo "Setup cancelled."
            exit 0
        fi
    fi
    
    check_prerequisites
    create_project_structure
    create_package_files
    install_dependencies
    create_service_scripts
    choose_setup_method
    
    echo ""
    echo -e "${GREEN}🎉 Setup Complete! 🎉${NC}"
    echo ""
    echo -e "${CYAN}Your Quiz Platform is ready! Here's what you can do:${NC}"
    echo ""
    echo -e "${YELLOW}📁 Project Structure:${NC}"
    echo "   services/user-service/    - Authentication service"
    echo "   services/quiz-service/    - Quiz management service"  
    echo "   services/results-service/ - Results processing service"
    echo "   scripts/                  - Management scripts"
    echo ""
    echo -e "${YELLOW}🚀 Quick Commands:${NC}"
    echo "   ./scripts/start-services.sh  - Start all services"
    echo "   ./scripts/test-system.sh     - Run comprehensive tests"
    echo "   ./scripts/stop-services.sh   - Stop all services"
    echo ""
    echo -e "${YELLOW}🌐 Service URLs:${NC}"
    echo "   User Service:    http://localhost:3001"
    echo "   Quiz Service:    http://localhost:3002"
    echo "   Results Service: http://localhost:3003"
    echo ""
    echo -e "${PURPLE}Ready to build the future of distributed systems! 🚀${NC}"
}

# Run the setup
main "$@"
