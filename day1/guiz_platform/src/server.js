// Main server entry point
// This will be expanded as we build the application

const express = require('express');
const app = express();
const PORT = process.env.PORT || 3000;

// Basic middleware setup
app.use(express.json());

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ 
    status: 'OK', 
    message: 'AI Quiz Platform - Day 1 Setup Complete',
    timestamp: new Date().toISOString()
  });
});

// Start server
if (require.main === module) {
  app.listen(PORT, () => {
    console.log(`🚀 Server running on port ${PORT}`);
    console.log(`📝 Visit http://localhost:${PORT}/health to verify setup`);
  });
}

module.exports = app;
