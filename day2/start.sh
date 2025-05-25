# Create the main project structure
mkdir quiz-platform-microservices
cd quiz-platform-microservices

# Create service directories
mkdir -p services/user-service services/quiz-service services/results-service
mkdir -p shared/utils shared/middleware
mkdir docker

# Create configuration files
touch docker-compose.yml
touch .env
touch README.md

# Initialize each service
cd services/user-service && npm init -y
cd ../quiz-service && npm init -y  
cd ../results-service && npm init -y
cd ../../

# Install dependencies for all services
cd services/user-service && npm install express cors helmet morgan jsonwebtoken bcryptjs
cd ../quiz-service && npm install express cors helmet morgan
cd ../results-service && npm install express cors helmet morgan
cd ../../

echo "Project structure created successfully!"
tree -I node_modules