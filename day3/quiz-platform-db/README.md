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
