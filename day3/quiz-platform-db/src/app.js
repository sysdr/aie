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
