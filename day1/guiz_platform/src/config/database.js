// Database configuration management
// This file will grow to handle connection pooling,
// environment-specific settings, and connection health monitoring

const config = {
  development: {
    mongodb: {
      uri: process.env.MONGODB_URI_DEV || 'mongodb://localhost:27017/ai-quiz-dev',
      options: {
        useNewUrlParser: true,
        useUnifiedTopology: true,
        maxPoolSize: 10,
        serverSelectionTimeoutMS: 5000,
        socketTimeoutMS: 45000,
      }
    }
  },
  test: {
    mongodb: {
      uri: process.env.MONGODB_URI_TEST || 'mongodb://localhost:27017/ai-quiz-test',
      options: {
        useNewUrlParser: true,
        useUnifiedTopology: true,
      }
    }
  },
  production: {
    mongodb: {
      uri: process.env.MONGODB_URI_PROD,
      options: {
        useNewUrlParser: true,
        useUnifiedTopology: true,
        maxPoolSize: 20,
        serverSelectionTimeoutMS: 5000,
        socketTimeoutMS: 45000,
      }
    }
  }
};

module.exports = config;
