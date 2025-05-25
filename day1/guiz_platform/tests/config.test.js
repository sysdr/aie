const config = require('../src/config/database');

describe('Configuration Management', () => {
  test('should load development configuration', () => {
    expect(config.development).toBeDefined();
    expect(config.development.mongodb).toBeDefined();
    expect(config.development.mongodb.uri).toContain('mongodb://');
  });

  test('should have proper MongoDB options', () => {
    const mongoConfig = config.development.mongodb;
    expect(mongoConfig.options.useNewUrlParser).toBe(true);
    expect(mongoConfig.options.useUnifiedTopology).toBe(true);
  });

  test('should have all environment configurations', () => {
    expect(config.development).toBeDefined();
    expect(config.test).toBeDefined();
    expect(config.production).toBeDefined();
  });
});
