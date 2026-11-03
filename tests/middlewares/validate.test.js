const { describe, it } = require('node:test');
const assert = require('node:assert');
const { z } = require('zod');
const validate = require('../../src/middlewares/validate');

describe('validate middleware', () => {
  it('calls next() and updates req data with parsed output when valid', () => {
    const middleware = validate({
      body: z.object({ title: z.string().trim() }),
    });

    const req = { body: { title: '  Trimmed Title  ' } };
    const res = {};
    let nextCalled = false;

    middleware(req, res, (err) => {
      assert.strictEqual(err, undefined);
      nextCalled = true;
    });

    assert.strictEqual(nextCalled, true);
    assert.strictEqual(req.body.title, 'Trimmed Title');
  });

  it('responds with 400 and structured error array when validation fails', () => {
    const middleware = validate({
      body: z.object({ title: z.string({ required_error: 'Title is required' }) }),
    });

    const req = { body: {} };
    let statusCode = null;
    let jsonPayload = null;

    const res = {
      status(code) {
        statusCode = code;
        return this;
      },
      json(data) {
        jsonPayload = data;
        return this;
      },
    };

    middleware(req, res, () => {
      assert.fail('next() should not be called on validation failure');
    });

    assert.strictEqual(statusCode, 400);
    assert.strictEqual(jsonPayload.success, false);
    assert.strictEqual(jsonPayload.message, 'Validation failed');
    assert.strictEqual(Array.isArray(jsonPayload.errors), true);
    assert.strictEqual(jsonPayload.errors[0].field, 'title');
    assert.strictEqual(jsonPayload.errors[0].message, 'Title is required');
  });
});
