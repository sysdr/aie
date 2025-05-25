# Start with Node.js base image - like choosing your foundation
FROM node:18-alpine

# Set working directory inside container
WORKDIR /app

# Copy package files first - Docker optimizes layers this way
COPY package*.json ./

# Install dependencies - like gathering all your cooking ingredients
RUN npm install

# Copy the rest of your application code
COPY . .

# Expose the port this service runs on
EXPOSE 3001

# Add health check - Docker can verify service is working
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:3001/health || exit 1

# Command to start the service
CMD ["npm", "start"]