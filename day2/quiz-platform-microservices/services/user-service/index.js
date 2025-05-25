// services/user-service/index.js
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');

const app = express();
const PORT = process.env.PORT || 3001;

// Security and logging middleware - just like having security guards and cameras
app.use(helmet()); // Protects against common vulnerabilities
app.use(cors()); // Allows cross-origin requests from frontend
app.use(morgan('combined')); // Logs all requests for debugging
app.use(express.json()); // Parses JSON request bodies

// In-memory user storage (in production, this would be a database)
let users = [
    { id: 1, username: 'demo_user', email: 'demo@quiz.com', password: 'hashed_password' }
];
let nextUserId = 2;

// Health check endpoint - tells load balancers this service is running
app.get('/health', (req, res) => {
    res.json({ 
        status: 'healthy', 
        service: 'user-service',
        timestamp: new Date().toISOString(),
        uptime: process.uptime()
    });
});

// User registration - like signing up for a new account
app.post('/api/users/register', (req, res) => {
    const { username, email, password } = req.body;
    
    // Input validation - never trust user input
    if (!username || !email || !password) {
        return res.status(400).json({ 
            error: 'Missing required fields',
            required: ['username', 'email', 'password']
        });
    }
    
    // Check if user already exists
    const existingUser = users.find(u => u.email === email || u.username === username);
    if (existingUser) {
        return res.status(409).json({ error: 'User already exists' });
    }
    
    // Create new user (in production, password would be properly hashed)
    const newUser = {
        id: nextUserId++,
        username,
        email,
        password: `hashed_${password}`, // Simplified for demo
        createdAt: new Date().toISOString()
    };
    
    users.push(newUser);
    
    // Return user without password for security
    const { password: _, ...userResponse } = newUser;
    res.status(201).json({ 
        message: 'User created successfully',
        user: userResponse 
    });
});

// User login - authenticating existing users
app.post('/api/users/login', (req, res) => {
    const { email, password } = req.body;
    
    if (!email || !password) {
        return res.status(400).json({ error: 'Email and password required' });
    }
    
    // Find user by email
    const user = users.find(u => u.email === email);
    if (!user || user.password !== `hashed_${password}`) {
        return res.status(401).json({ error: 'Invalid credentials' });
    }
    
    // In production, return a JWT token here
    const { password: _, ...userResponse } = user;
    res.json({ 
        message: 'Login successful',
        user: userResponse,
        token: `fake_jwt_token_for_user_${user.id}` // Simplified for demo
    });
});

// Get user profile - retrieving user information
app.get('/api/users/profile/:id', (req, res) => {
    const userId = parseInt(req.params.id);
    const user = users.find(u => u.id === userId);
    
    if (!user) {
        return res.status(404).json({ error: 'User not found' });
    }
    
    const { password: _, ...userResponse } = user;
    res.json(userResponse);
});

// List all users - useful for development and debugging
app.get('/api/users', (req, res) => {
    const usersWithoutPasswords = users.map(({ password, ...user }) => user);
    res.json({
        users: usersWithoutPasswords,
        total: usersWithoutPasswords.length
    });
});

// Error handling middleware - catches any uncaught errors
app.use((err, req, res, next) => {
    console.error(err.stack);
    res.status(500).json({ 
        error: 'Something went wrong!',
        message: process.env.NODE_ENV === 'development' ? err.message : 'Internal server error'
    });
});

// 404 handler for unknown routes
app.use('*', (req, res) => {
    res.status(404).json({ 
        error: 'Route not found',
        availableRoutes: [
            'GET /health',
            'POST /api/users/register',
            'POST /api/users/login',
            'GET /api/users/profile/:id',
            'GET /api/users'
        ]
    });
});

app.listen(PORT, () => {
    console.log(`🔐 User Service running on port ${PORT}`);
    console.log(`🏥 Health check: http://localhost:${PORT}/health`);
    console.log(`👥 User endpoints: http://localhost:${PORT}/api/users`);
});