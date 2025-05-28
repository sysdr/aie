-- Create test database
CREATE DATABASE quiz_test_db;
GRANT ALL PRIVILEGES ON DATABASE quiz_test_db TO quiz_user;

-- Connect to main database and create extensions if needed
\c quiz_db;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Connect to test database and create extensions
\c quiz_test_db;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
