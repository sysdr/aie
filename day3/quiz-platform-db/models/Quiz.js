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
