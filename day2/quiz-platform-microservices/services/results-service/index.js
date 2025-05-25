// services/results-service/index.js
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');

const app = express();
const PORT = process.env.PORT || 3003;

app.use(helmet());
app.use(cors());
app.use(morgan('combined'));
app.use(express.json());

// In-memory storage for quiz results and leaderboards
// In production, this would be a high-performance database like Redis
let results = [];
let leaderboard = [];
let nextResultId = 1;

// Health check - critical for load balancers and monitoring systems
app.get('/health', (req, res) => {
    res.json({ 
        status: 'healthy', 
        service: 'results-service',
        timestamp: new Date().toISOString(),
        totalResults: results.length,
        leaderboardSize: leaderboard.length
    });
});

// Submit quiz results - this is where the magic happens
app.post('/api/results/submit', async (req, res) => {
    const { userId, quizId, answers, timeSpent, startTime, endTime } = req.body;
    
    // Validation - never trust incoming data
    if (!userId || !quizId || !answers || !Array.isArray(answers)) {
        return res.status(400).json({ 
            error: 'Missing required fields',
            required: ['userId', 'quizId', 'answers']
        });
    }
    
    try {
        // In a real system, you'd call the Quiz Service API here
        // For this demo, we'll simulate fetching the quiz with correct answers
        const correctAnswers = getCorrectAnswers(quizId);
        
        if (!correctAnswers) {
            return res.status(404).json({ error: 'Quiz not found' });
        }
        
        // Calculate the score - this is the core business logic
        const score = calculateScore(answers, correctAnswers);
        const percentage = Math.round((score.correct / score.total) * 100);
        
        // Create the result record
        const result = {
            id: nextResultId++,
            userId,
            quizId,
            answers,
            score: score.correct,
            totalQuestions: score.total,
            percentage,
            timeSpent: timeSpent || 0,
            startTime: startTime || new Date().toISOString(),
            endTime: endTime || new Date().toISOString(),
            submittedAt: new Date().toISOString()
        };
        
        results.push(result);
        
        // Update leaderboard - this is where competitive features come alive
        updateLeaderboard(userId, result);
        
        res.status(201).json({ 
            message: 'Results submitted successfully',
            result: {
                id: result.id,
                score: result.score,
                totalQuestions: result.totalQuestions,
                percentage: result.percentage,
                timeSpent: result.timeSpent
            },
            leaderboardPosition: getLeaderboardPosition(userId)
        });
        
    } catch (error) {
        console.error('Error processing results:', error);
        res.status(500).json({ error: 'Failed to process results' });
    }
});

// Get user's quiz history - shows progression over time
app.get('/api/results/user/:userId', (req, res) => {
    const userId = parseInt(req.params.userId);
    const userResults = results.filter(r => r.userId === userId);
    
    if (userResults.length === 0) {
        return res.json({ 
            message: 'No results found for this user',
            results: [],
            statistics: null
        });
    }
    
    // Calculate user statistics - this gives insights into learning progress
    const statistics = {
        totalQuizzesTaken: userResults.length,
        averageScore: Math.round(
            userResults.reduce((sum, r) => sum + r.percentage, 0) / userResults.length
        ),
        bestScore: Math.max(...userResults.map(r => r.percentage)),
        totalTimeSpent: userResults.reduce((sum, r) => sum + (r.timeSpent || 0), 0),
        recentActivity: userResults.slice(-5).reverse() // Last 5 quizzes
    };
    
    res.json({
        userId,
        results: userResults.reverse(), // Most recent first
        statistics
    });
});

// Get results for a specific quiz - useful for analytics
app.get('/api/results/quiz/:quizId', (req, res) => {
    const quizId = parseInt(req.params.quizId);
    const quizResults = results.filter(r => r.quizId === quizId);
    
    if (quizResults.length === 0) {
        return res.json({ 
            message: 'No results found for this quiz',
            results: [],
            analytics: null
        });
    }
    
    // Generate quiz analytics - this data helps improve quiz quality
    const analytics = {
        totalAttempts: quizResults.length,
        averageScore: Math.round(
            quizResults.reduce((sum, r) => sum + r.percentage, 0) / quizResults.length
        ),
        highestScore: Math.max(...quizResults.map(r => r.percentage)),
        averageTimeSpent: Math.round(
            quizResults.reduce((sum, r) => sum + (r.timeSpent || 0), 0) / quizResults.length
        ),
        passRate: Math.round(
            (quizResults.filter(r => r.percentage >= 70).length / quizResults.length) * 100
        )
    };
    
    res.json({
        quizId,
        results: quizResults,
        analytics
    });
});

// Get global leaderboard - the competitive element that drives engagement
app.get('/api/leaderboard', (req, res) => {
    const limit = parseInt(req.query.limit) || 10;
    const topUsers = leaderboard
        .sort((a, b) => b.averageScore - a.averageScore || b.totalQuizzes - a.totalQuizzes)
        .slice(0, limit);
    
    res.json({
        leaderboard: topUsers,
        totalUsers: leaderboard.length,
        lastUpdated: new Date().toISOString()
    });
});

// Helper function to simulate getting correct answers from Quiz Service
function getCorrectAnswers(quizId) {
    // In production, this would be an HTTP call to the Quiz Service
    // For demo purposes, we'll return mock correct answers
    const mockQuizAnswers = {
        1: [0, 1], // JavaScript Fundamentals quiz
        2: [1]     // System Design Basics quiz
    };
    
    return mockQuizAnswers[quizId];
}

// Core business logic - calculates quiz scores
function calculateScore(userAnswers, correctAnswers) {
    let correct = 0;
    const total = correctAnswers.length;
    
    for (let i = 0; i < total; i++) {
        if (userAnswers[i] === correctAnswers[i]) {
            correct++;
        }
    }
    
    return { correct, total };
}

// Updates the global leaderboard - this is where gamification happens
function updateLeaderboard(userId, newResult) {
    let userEntry = leaderboard.find(entry => entry.userId === userId);
    
    if (!userEntry) {
        // New user on leaderboard
        userEntry = {
            userId,
            totalQuizzes: 0,
            totalScore: 0,
            averageScore: 0,
            bestScore: 0,
            lastActivity: null
        };
        leaderboard.push(userEntry);
    }
    
    // Update user's leaderboard stats
    userEntry.totalQuizzes++;
    userEntry.totalScore += newResult.percentage;
    userEntry.averageScore = Math.round(userEntry.totalScore / userEntry.totalQuizzes);
    userEntry.bestScore = Math.max(userEntry.bestScore, newResult.percentage);
    userEntry.lastActivity = new Date().toISOString();
}

// Helper function to find user's current leaderboard position
function getLeaderboardPosition(userId) {
    const sortedLeaderboard = leaderboard
        .sort((a, b) => b.averageScore - a.averageScore || b.totalQuizzes - a.totalQuizzes);
    
    const position = sortedLeaderboard.findIndex(entry => entry.userId === userId) + 1;
    return position || null;
}

// Error handling middleware
app.use((err, req, res, next) => {
    console.error('Results Service Error:', err.stack);
    res.status(500).json({ 
        error: 'Something went wrong in Results Service!',
        message: process.env.NODE_ENV === 'development' ? err.message : 'Internal server error'
    });
});

// 404 handler
app.use('*', (req, res) => {
    res.status(404).json({ 
        error: 'Route not found',
        availableRoutes: [
            'GET /health',
            'POST /api/results/submit',
            'GET /api/results/user/:userId',
            'GET /api/results/quiz/:quizId',
            'GET /api/leaderboard'
        ]
    });
});

app.listen(PORT, () => {
    console.log(`🏆 Results Service running on port ${PORT}`);
    console.log(`🏥 Health check: http://localhost:${PORT}/health`);
    console.log(`📊 Leaderboard: http://localhost:${PORT}/api/leaderboard`);
});