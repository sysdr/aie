const request = require('supertest');
const app = require('../../src/server');

describe('Integration Test Setup', () => {
  test('should respond to health check', async () => {
    const response = await request(app)
      .get('/health')
      .expect(200);

    expect(response.body.status).toBe('OK');
    expect(response.body.message).toContain('AI Quiz Platform');
  });

  test('should have proper JSON response format', async () => {
    const response = await request(app)
      .get('/health')
      .expect('Content-Type', /json/);

    expect(response.body.timestamp).toBeDefined();
  });
});
