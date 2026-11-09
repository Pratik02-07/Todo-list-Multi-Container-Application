const { test, describe } = require('node:test');
const assert = require('node:assert/strict');
const { validateEnv } = require('../backend/src/utils/env');

describe('Environment Variable Validation', () => {
  test('returns default environment configuration when empty', () => {
    const env = validateEnv({});
    assert.equal(env.NODE_ENV, 'development');
    assert.equal(env.PORT, 3000);
    assert.equal(env.MONGO_URI, 'mongodb://mongo:27017/tododb');
  });

  test('accepts valid custom environment variables', () => {
    const customConfig = {
      NODE_ENV: 'production',
      PORT: '8080',
      MONGO_URI: 'mongodb://cluster0.mongodb.net/prod-todo',
    };
    const env = validateEnv(customConfig);
    assert.equal(env.NODE_ENV, 'production');
    assert.equal(env.PORT, 8080);
    assert.equal(env.MONGO_URI, 'mongodb://cluster0.mongodb.net/prod-todo');
  });

  test('rejects invalid NODE_ENV value', () => {
    assert.throws(
      () => validateEnv({ NODE_ENV: 'staging' }),
      /Invalid environment variables/
    );
  });

  test('rejects invalid PORT value out of range', () => {
    assert.throws(
      () => validateEnv({ PORT: '99999' }),
      /Invalid environment variables/
    );
  });
});
