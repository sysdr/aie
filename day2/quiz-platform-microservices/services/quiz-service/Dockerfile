FROM node:18-alpine

WORKDIR /app

# Copy and install dependencies first for better caching
COPY package*.json ./
RUN npm install

# Copy application code
COPY . .

# This service runs on port 3002
EXPOSE 3002

# Health check for quiz service
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:3002/health || exit 1

CMD ["npm", "start"]