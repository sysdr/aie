// MongoDB initialization script
db = db.getSiblingDB('quiz_platform');

// Create collections with validation
db.createCollection('users', {
  validator: {
    $jsonSchema: {
      bsonType: 'object',
      required: ['username', 'email', 'hashed_password', 'is_active', 'created_at'],
      properties: {
        username: {
          bsonType: 'string',
          minLength: 3,
          maxLength: 50,
          description: 'Username must be a string between 3-50 characters'
        },
        email: {
          bsonType: 'string',
          pattern: '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,},
          description: 'Must be a valid email address'
        },
        hashed_password: {
          bsonType: 'string',
          description: 'Hashed password is required'
        },
        full_name: {
          bsonType: 'string',
          description: 'Full name of the user'
        },
        is_active: {
          bsonType: 'bool',
          description: 'User account status'
        },
        created_at: {
          bsonType: 'date',
          description: 'Account creation timestamp'
        },
        last_login: {
          bsonType: 'date',
          description: 'Last login timestamp'
        },
        last_activity: {
          bsonType: 'date',
          description: 'Last activity timestamp'
        }
      }
    }
  }
});

// Create unique indexes
db.users.createIndex({ username: 1 }, { unique: true });
db.users.createIndex({ email: 1 }, { unique: true });
db.users.createIndex({ created_at: 1 });
db.users.createIndex({ last_login: 1 });

print('✅ MongoDB initialization completed successfully!');
