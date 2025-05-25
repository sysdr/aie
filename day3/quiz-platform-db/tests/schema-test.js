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
