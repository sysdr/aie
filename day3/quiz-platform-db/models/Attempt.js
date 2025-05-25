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
