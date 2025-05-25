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
