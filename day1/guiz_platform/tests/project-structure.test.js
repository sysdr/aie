const fs = require('fs');
const path = require('path');

describe('Project Structure Validation', () => {
  test('should have all required directories', () => {
    const requiredDirs = [
      'src',
      'docs', 
      'tests',
      'scripts'
    ];
    
    requiredDirs.forEach(dir => {
      expect(fs.existsSync(path.join(__dirname, '..', dir))).toBe(true);
    });
  });

  test('should have essential documentation files', () => {
    const requiredFiles = [
      'README.md',
      'package.json', 
      'docs/project-plan/MASTER_PLAN.md'
    ];
    
    requiredFiles.forEach(file => {
      expect(fs.existsSync(path.join(__dirname, '..', file))).toBe(true);
    });
  });

  test('should have proper src structure', () => {
    const srcDirs = [
      'src/config',
      'src/controllers',
      'src/middleware', 
      'src/models',
      'src/services',
      'src/utils'
    ];

    srcDirs.forEach(dir => {
      expect(fs.existsSync(path.join(__dirname, '..', dir))).toBe(true);
    });
  });
});
