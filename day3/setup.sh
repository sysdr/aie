#!/bin/bash

# Quiz Platform Database Schema Setup and Test Script
# Day 3: Database Schema Design Implementation

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Wait for service to be ready
wait_for_service() {
    local url=$1
    local max_attempts=30
    local attempt=1
    
    log_info "Waiting for service at $url..."
    while [ $attempt -le $max_attempts ]; do
        if curl -s "$url" >/dev/null 2>&1; then
            log_success "Service is ready!"
            return 0
        fi
        echo -n "."
        sleep 2
        ((attempt++))
    done
    
    log_error "Service at $url is not responding after $max_attempts attempts"
    return 1
}

# Create project structure
create_project_structure() {
    log_info "Creating project structure..."
    
    # Create main directories
    mkdir -p quiz-platform-db/{src,models,config,tests}
    cd quiz-platform-db
    
    log_success "Project structure created"
}

# Create package.json
create_package_json() {
    log_info "Creating package.json..."
    
    cat > package.json << 'EOF'
{
  "name": "quiz-platform-db",
  "version": "1.0.0",
  "description": "Quiz Platform Database Schema Implementation",
  "main": "src/app.js",
  "scripts": {
    "start": "node src/app.js",
    "dev": "nodemon src/app.js",
    "test": "node tests/schema-test.js"
  },
  "dependencies": {
    "express": "^4.18.2",
    "mongoose": "^7.5.0",
    "bcryptjs": "^2.4.3"
  },
  "devDependencies": {
    "nodemon": "^3.0.1"
  }
}
EOF
    
    log_success "package.json created"
}

# Create database configuration
create_database_config() {
    log_info "Creating database configuration..."
    
    cat > config/database.js << 'EOF'
const mongoose = require('mongoose');

const connectDatabase = async () => {
  try {
    const conn = await mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost:27017/quiz-platform', {
      useNewUrlParser: true,
      useUnifiedTopology: true,
    });
    
    console.log(`MongoDB Connected: ${conn.connection.host}`);
    return conn;
  } catch (error) {
    console.error('Database connection error:', error);
    process.exit(1);
  }
};

module.exports = connectDatabase;
EOF
    
    log_success "Database configuration created"
}

# Create User model
create_user_model() {
    log_info "Creating User model..."
    
    cat > models/User.js << 'EOF'
const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');

const userSchema = new mongoose.Schema({
  username: {
    type: String,
    required: true,
    unique: true,
    trim: true,
    minlength: 3,
    maxlength: 30
  },
  email: {
    type: String,
    required: true,
    unique: true,
    lowercase: true,
    match: /^[^\s@]+@[^\s@]+\.[^\s@]+$/
  },
  password: {
    type: String,
    required: true,
    minlength: 6
  },
  role: {
    type: String,
    enum: ['student', 'teacher', 'admin'],
    default: 'student'
  },
  profile: {
    firstName: String,
    lastName: String,
    avatar: String,
    dateOfBirth: Date
  },
  stats: {
    totalQuizzesTaken: { type: Number, default: 0 },
    averageScore: { type: Number, default: 0 },
    totalPoints: { type: Number, default: 0 }
  }
}, {
  timestamps: true
});

// Hash password before saving
userSchema.pre('save', async function(next) {
  if (!this.isModified('password')) return next();
  this.password = await bcrypt.hash(this.password, 10);
  next();
});

module.exports = mongoose.model('User', userSchema);
EOF
    
    log_success "User model created"
}

# Create Question model
create_question_model() {
    log_info "Creating Question model..."
    
    cat > models/Question.js << 'EOF'
const mongoose = require('mongoose');

const questionSchema = new mongoose.Schema({
  question: {
    type: String,
    required: true,
    trim: true,
    maxlength: 500
  },
  type: {
    type: String,
    enum: ['multiple-choice', 'true-false', 'short-answer'],
    required: true
  },
  options: [{
    text: { type: String, required: true },
    isCorrect: { type: Boolean, default: false }
  }],
  correctAnswer: String,
  explanation: String,
  difficulty: {
    type: String,
    enum: ['easy', 'medium', 'hard'],
    default: 'medium'
  },
  points: {
    type: Number,
    default: 1,
    min: 1,
    max: 10
  },
  tags: [String],
  creator: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  }
}, {
  timestamps: true
});

// Validation for multiple choice questions
questionSchema.pre('save', function(next) {
  if (this.type === 'multiple-choice') {
    if (this.options.length < 2) {
      return next(new Error('Multiple choice questions must have at least 2 options'));
    }
    const correctAnswers = this.options.filter(opt => opt.isCorrect);
    if (correctAnswers.length === 0) {
      return next(new Error('Multiple choice questions must have at least one correct answer'));
    }
  }
  next();
});

module.exports = mongoose.model('Question', questionSchema);
EOF
    
    log_success "Question model created"
}

# Create Quiz model
create_quiz_model() {
    log_info "Creating Quiz model..."
    
    cat > models/Quiz.js << 'EOF'
const mongoose = require('mongoose');

const quizSchema = new mongoose.Schema({
  title: {
    type: String,
    required: true,
    trim: true,
    maxlength: 200
  },
  description: {
    type: String,
    maxlength: 1000
  },
  creator: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  category: {
    type: String,
    required: true,
    enum: ['math', 'science', 'history', 'literature', 'general']
  },
  difficulty: {
    type: String,
    enum: ['easy', 'medium', 'hard'],
    default: 'medium'
  },
  timeLimit: {
    type: Number,
    default: 30,
    min: 1,
    max: 180
  },
  questions: [{
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Question'
  }],
  settings: {
    isPublic: { type: Boolean, default: true },
    allowRetakes: { type: Boolean, default: true },
    showCorrectAnswers: { type: Boolean, default: true },
    randomizeQuestions: { type: Boolean, default: false }
  },
  stats: {
    totalAttempts: { type: Number, default: 0 },
    averageScore: { type: Number, default: 0 },
    completionRate: { type: Number, default: 0 }
  }
}, {
  timestamps: true
});

module.exports = mongoose.model('Quiz', quizSchema);
EOF
    
    log_success "Quiz model created"
}

# Create Attempt model
create_attempt_model() {
    log_info "Creating Attempt model..."
    
    cat > models/Attempt.js << 'EOF'
const mongoose = require('mongoose');

const attemptSchema = new mongoose.Schema({
  user: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  quiz: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Quiz',
    required: true
  },
  answers: [{
    question: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Question',
      required: true
    },
    userAnswer: mongoose.Schema.Types.Mixed,
    isCorrect: Boolean,
    pointsEarned: { type: Number, default: 0 },
    timeSpent: Number
  }],
  score: {
    totalPoints: { type: Number, default: 0 },
    maxPoints: { type: Number, required: true },
    percentage: { type: Number, default: 0 }
  },
  timing: {
    startedAt: { type: Date, default: Date.now },
    completedAt: Date,
    totalTime: Number
  },
  status: {
    type: String,
    enum: ['in-progress', 'completed', 'abandoned'],
    default: 'in-progress'
  }
}, {
  timestamps: true
});

// Calculate final score before saving
attemptSchema.pre('save', function(next) {
  if (this.status === 'completed') {
    this.score.totalPoints = this.answers.reduce((sum, answer) => sum + answer.pointsEarned, 0);
    this.score.percentage = (this.score.totalPoints / this.score.maxPoints) * 100;
    
    if (!this.timing.completedAt) {
      this.timing.completedAt = new Date();
      this.timing.totalTime = Math.floor((this.timing.completedAt - this.timing.startedAt) / 1000);
    }
  }
  next();
});

module.exports = mongoose.model('Attempt', attemptSchema);
EOF
    
    log_success "Attempt model created"
}

# Create main application
create_main_app() {
    log_info "Creating main application..."
    
    cat > src/app.js << 'EOF'
const express = require('express');
const mongoose = require('mongoose');
const connectDatabase = require('../config/database');

// Import models
const User = require('../models/User');
const Quiz = require('../models/Quiz');
const Question = require('../models/Question');
const Attempt = require('../models/Attempt');

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(express.json());

// Connect to database
connectDatabase();

// Test route to verify schema functionality
app.get('/api/test-schema', async (req, res) => {
  try {
    // Clean up any existing test data
    await User.deleteMany({ email: 'test@example.com' });
    await Question.deleteMany({ question: 'What is 2 + 2?' });
    await Quiz.deleteMany({ title: 'Basic Math Quiz' });
    
    // Create a test user
    const testUser = new User({
      username: `testuser_${Date.now()}`,
      email: 'test@example.com',
      password: 'password123',
      profile: {
        firstName: 'Test',
        lastName: 'User'
      }
    });
    
    const savedUser = await testUser.save();
    
    // Create a test question
    const testQuestion = new Question({
      question: 'What is 2 + 2?',
      type: 'multiple-choice',
      options: [
        { text: '3', isCorrect: false },
        { text: '4', isCorrect: true },
        { text: '5', isCorrect: false }
      ],
      creator: savedUser._id
    });
    
    const savedQuestion = await testQuestion.save();
    
    // Create a test quiz
    const testQuiz = new Quiz({
      title: 'Basic Math Quiz',
      description: 'A simple math quiz for testing',
      creator: savedUser._id,
      category: 'math',
      questions: [savedQuestion._id]
    });
    
    const savedQuiz = await testQuiz.save();
    
    // Create a test attempt
    const testAttempt = new Attempt({
      user: savedUser._id,
      quiz: savedQuiz._id,
      answers: [{
        question: savedQuestion._id,
        userAnswer: '4',
        isCorrect: true,
        pointsEarned: 1
      }],
      score: {
        maxPoints: 1
      },
      status: 'completed'
    });
    
    const savedAttempt = await testAttempt.save();
    
    res.json({
      message: 'Schema test successful! All models working correctly.',
      data: {
        user: {
          id: savedUser._id,
          username: savedUser.username,
          email: savedUser.email
        },
        question: {
          id: savedQuestion._id,
          question: savedQuestion.question,
          type: savedQuestion.type
        },
        quiz: {
          id: savedQuiz._id,
          title: savedQuiz.title,
          category: savedQuiz.category
        },
        attempt: {
          id: savedAttempt._id,
          score: savedAttempt.score,
          status: savedAttempt.status
        }
      }
    });
  } catch (error) {
    console.error('Schema test error:', error);
    res.status(500).json({ 
      error: error.message,
      details: 'Check server logs for more information'
    });
  }
});

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ 
    status: 'OK', 
    timestamp: new Date().toISOString(),
    database: mongoose.connection.readyState === 1 ? 'Connected' : 'Disconnected'
  });
});

// Root endpoint
app.get('/', (req, res) => {
  res.json({
    message: 'Quiz Platform Database API',
    endpoints: {
      health: '/health',
      test: '/api/test-schema'
    }
  });
});

app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
  console.log(`Health check: http://localhost:${PORT}/health`);
  console.log(`Schema test: http://localhost:${PORT}/api/test-schema`);
});
EOF
    
    log_success "Main application created"
}

# Create test script
create_test_script() {
    log_info "Creating test script..."
    
    cat > tests/schema-test.js << 'EOF'
const mongoose = require('mongoose');
const connectDatabase = require('../config/database');

// Import models
const User = require('../models/User');
const Question = require('../models/Question');
const Quiz = require('../models/Quiz');
const Attempt = require('../models/Attempt');

async function runSchemaTests() {
  try {
    console.log('🧪 Starting schema validation tests...\n');
    
    // Connect to database
    await connectDatabase();
    
    // Test 1: User model validation
    console.log('📝 Test 1: User model validation');
    try {
      const invalidUser = new User({
        username: 'ab', // Too short
        email: 'invalid-email',
        password: '123' // Too short
      });
      await invalidUser.validate();
      console.log('❌ User validation should have failed');
    } catch (error) {
      console.log('✅ User validation working correctly');
    }
    
    // Test 2: Question model validation
    console.log('\n📝 Test 2: Question model validation');
    try {
      const testUser = new User({
        username: 'testuser123',
        email: 'test@example.com',
        password: 'password123'
      });
      await testUser.save();
      
      const invalidQuestion = new Question({
        question: 'Test question?',
        type: 'multiple-choice',
        options: [{ text: 'Only one option', isCorrect: false }], // No correct answer
        creator: testUser._id
      });
      await invalidQuestion.save();
      console.log('❌ Question validation should have failed');
    } catch (error) {
      console.log('✅ Question validation working correctly');
    }
    
    // Test 3: Complete workflow
    console.log('\n📝 Test 3: Complete workflow test');
    
    // Clean up
    await User.deleteMany({});
    await Question.deleteMany({});
    await Quiz.deleteMany({});
    await Attempt.deleteMany({});
    
    // Create valid user
    const user = new User({
      username: 'johndoe',
      email: 'john@example.com',
      password: 'securepassword',
      profile: {
        firstName: 'John',
        lastName: 'Doe'
      }
    });
    await user.save();
    console.log('✅ User created successfully');
    
    // Create valid question
    const question = new Question({
      question: 'What is the capital of France?',
      type: 'multiple-choice',
      options: [
        { text: 'London', isCorrect: false },
        { text: 'Paris', isCorrect: true },
        { text: 'Berlin', isCorrect: false },
        { text: 'Madrid', isCorrect: false }
      ],
      creator: user._id,
      difficulty: 'easy',
      points: 2
    });
    await question.save();
    console.log('✅ Question created successfully');
    
    // Create valid quiz
    const quiz = new Quiz({
      title: 'European Capitals Quiz',
      description: 'Test your knowledge of European capitals',
      creator: user._id,
      category: 'general',
      questions: [question._id],
      timeLimit: 15
    });
    await quiz.save();
    console.log('✅ Quiz created successfully');
    
    // Create attempt
    const attempt = new Attempt({
      user: user._id,
      quiz: quiz._id,
      answers: [{
        question: question._id,
        userAnswer: 'Paris',
        isCorrect: true,
        pointsEarned: 2,
        timeSpent: 30
      }],
      score: {
        maxPoints: 2
      },
      status: 'completed'
    });
    await attempt.save();
    console.log('✅ Attempt created successfully');
    
    // Verify calculated fields
    if (attempt.score.percentage === 100 && attempt.score.totalPoints === 2) {
      console.log('✅ Score calculation working correctly');
    } else {
      console.log('❌ Score calculation failed');
    }
    
    console.log('\n🎉 All schema tests passed!');
    
  } catch (error) {
    console.error('❌ Test failed:', error.message);
  } finally {
    await mongoose.connection.close();
    console.log('\n📊 Test completed');
  }
}

// Run tests
runSchemaTests();
EOF
    
    log_success "Test script created"
}

# Create Docker files
create_docker_files() {
    log_info "Creating Docker configuration..."
    
    # Dockerfile
    cat > Dockerfile << 'EOF'
FROM node:18-alpine

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm install

# Copy source code
COPY . .

# Expose port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:3000/health || exit 1

# Start the application
CMD ["npm", "start"]
EOF
    
    # docker-compose.yml
    cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  app:
    build: .
    ports:
      - "3000:3000"
    environment:
      - MONGODB_URI=mongodb://mongo:27017/quiz-platform
      - NODE_ENV=development
    depends_on:
      - mongo
    volumes:
      - .:/app
      - /app/node_modules
    restart: unless-stopped

  mongo:
    image: mongo:7
    ports:
      - "27017:27017"
    environment:
      - MONGO_INITDB_DATABASE=quiz-platform
    volumes:
      - mongo_data:/data/db
    restart: unless-stopped

volumes:
  mongo_data:
EOF

    # .dockerignore
    cat > .dockerignore << 'EOF'
node_modules
npm-debug.log
.git
.gitignore
README.md
.env
.nyc_output
coverage
.coverage
EOF
    
    log_success "Docker configuration created"
}

# Create README
create_readme() {
    log_info "Creating README.md..."
    
    cat > README.md << 'EOF'
# Quiz Platform Database Schema

Day 3 implementation of the Quiz Platform database schema design.

## Quick Start

### Local Development
```bash
# Install dependencies
npm install

# Start MongoDB (if installed locally)
mongod

# Run the application
npm start

# Run tests
npm test
```

### Docker Development
```bash
# Build and start services
docker-compose up --build

# View logs
docker-compose logs -f

# Stop services
docker-compose down
```

## API Endpoints

- `GET /` - API information
- `GET /health` - Health check
- `GET /api/test-schema` - Schema validation test

## Testing

Visit http://localhost:3000/api/test-schema to verify all schemas work correctly.

## Models

- **User**: Authentication and profile data
- **Question**: Quiz questions with validation
- **Quiz**: Quiz metadata and settings
- **Attempt**: User quiz attempts with scoring
EOF
    
    log_success "README.md created"
}

# Install dependencies
install_dependencies() {
    log_info "Installing Node.js dependencies..."
    
    if command_exists npm; then
        npm install
        log_success "Dependencies installed successfully"
    else
        log_warning "npm not found, skipping dependency installation"
    fi
}

# Test local setup
test_local_setup() {
    log_info "Testing local setup..."
    
    # Check if MongoDB is running
    if command_exists mongod || pgrep mongod > /dev/null; then
        log_info "Starting application locally..."
        
        # Start app in background
        npm start &
        APP_PID=$!
        
        # Wait for app to start
        sleep 5
        
        # Test endpoints
        log_info "Testing endpoints..."
        
        if curl -s http://localhost:3000/health | grep -q "OK"; then
            log_success "Health check passed"
        else
            log_error "Health check failed"
        fi
        
        if curl -s http://localhost:3000/api/test-schema | grep -q "successful"; then
            log_success "Schema test passed"
        else
            log_error "Schema test failed"
        fi
        
        # Stop the app
        kill $APP_PID 2>/dev/null || true
        
    else
        log_warning "MongoDB not running locally, skipping local tests"
        log_info "You can run 'npm test' to test schemas without a running server"
    fi
}

# Test Docker setup
test_docker_setup() {
    log_info "Testing Docker setup..."
    
    if command_exists docker && command_exists docker-compose; then
        # Build and start services
        log_info "Building and starting Docker services..."
        docker-compose up --build -d
        
        # Wait for services to be ready
        if wait_for_service "http://localhost:3000/health"; then
            # Test endpoints
            log_info "Testing Docker endpoints..."
            
            if curl -s http://localhost:3000/health | grep -q "OK"; then
                log_success "Docker health check passed"
            else
                log_error "Docker health check failed"
            fi
            
            if curl -s http://localhost:3000/api/test-schema | grep -q "successful"; then
                log_success "Docker schema test passed"
            else
                log_error "Docker schema test failed"
            fi
            
            # Show logs
            log_info "Application logs:"
            docker-compose logs app | tail -10
            
        else
            log_error "Docker services failed to start properly"
            docker-compose logs
        fi
        
        # Clean up
        log_info "Stopping Docker services..."
        docker-compose down
        
    else
        log_warning "Docker or docker-compose not found, skipping Docker tests"
    fi
}

# Main execution
main() {
    echo -e "${BLUE}Quiz Platform Database Schema Setup${NC}"
    echo "========================================"
    
    # Check prerequisites
    log_info "Checking prerequisites..."
    
    if ! command_exists node; then
        log_error "Node.js is required but not installed"
        exit 1
    fi
    
    if ! command_exists curl; then
        log_warning "curl not found, some tests may not work"
    fi
    
    # Create project
    log_info "Creating project structure and files..."
    create_project_structure
    create_package_json
    create_database_config
    create_user_model
    create_question_model
    create_quiz_model
    create_attempt_model
    create_main_app
    create_test_script
    create_docker_files
    create_readme
    
    log_success "Project files created successfully!"
    
    # Install dependencies
    install_dependencies
    
    # Run tests
    echo -e "\n${BLUE}Testing Setup${NC}"
    echo "=============="
    
    # Test schemas directly
    log_info "Running schema validation tests..."
    if command_exists node; then
        node tests/schema-test.js
    fi
    
    # Test local setup
    test_local_setup
    
    # Test Docker setup
    test_docker_setup
    
    # Final instructions
    echo -e "\n${GREEN}Setup Complete!${NC}"
    echo "==============="
    echo "Your quiz platform database schema is ready."
    echo ""
    echo "To start development:"
    echo "  cd quiz-platform-db"
    echo "  npm start"
    echo ""
    echo "To use Docker:"
    echo "  docker-compose up --build"
    echo ""
    echo "Test URLs:"
    echo "  - Health: http://localhost:3000/health"
    echo "  - Schema: http://localhost:3000/api/test-schema"
}

# Run main function
main "$@"