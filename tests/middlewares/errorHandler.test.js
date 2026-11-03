const { describe, it } = require('node:test');
const assert = require('node:assert');
const errorHandler = require('../../src/middlewares/errorHandler');
const AppError = require('../../src/utils/AppError');

describe('errorHandler middleware', () => {
  const createMockRes = () => {
    const res = {
      statusCode: null,
      body: null,
      status(code) {
        this.statusCode = code;
        return this;
      },
      json(data) {
        this.body = data;
        return this;
      },
    };
    return res;
  };

  it('handles AppError with custom status code', () => {
    const err = new AppError('Todo not found', 404);
    const req = {};
    const res = createMockRes();

    errorHandler(err, req, res, () => {});

    assert.strictEqual(res.statusCode, 404);
    assert.strictEqual(res.body.success, false);
    assert.strictEqual(res.body.message, 'Todo not found');
  });

  it('handles malformed JSON SyntaxError with 400', () => {
    const err = new SyntaxError('Unexpected token in JSON');
    err.status = 400;
    const req = {};
    const res = createMockRes();

    errorHandler(err, req, res, () => {});

    assert.strictEqual(res.statusCode, 400);
    assert.strictEqual(res.body.success, false);
    assert.strictEqual(res.body.message, 'Invalid JSON format in request body');
  });

  it('handles Mongoose CastError with 400', () => {
    const err = new Error('Cast to ObjectId failed');
    err.name = 'CastError';
    err.value = 'invalid-mongo-id';
    const req = {};
    const res = createMockRes();

    errorHandler(err, req, res, () => {});

    assert.strictEqual(res.statusCode, 400);
    assert.strictEqual(res.body.success, false);
    assert.strictEqual(res.body.message, 'Invalid ID format: invalid-mongo-id');
  });

  it('handles Mongoose ValidationError with 400 and structured errors', () => {
    const err = new Error('Validation failed');
    err.name = 'ValidationError';
    err.errors = {
      title: { path: 'title', message: 'Path `title` is required.' },
    };
    const req = {};
    const res = createMockRes();

    errorHandler(err, req, res, () => {});

    assert.strictEqual(res.statusCode, 400);
    assert.strictEqual(res.body.success, false);
    assert.strictEqual(res.body.message, 'Validation failed');
    assert.deepStrictEqual(res.body.errors, [
      { field: 'title', message: 'Path `title` is required.' },
    ]);
  });

  it('handles generic unhandled error with 500', () => {
    const err = new Error('Unexpected database failure');
    const req = {};
    const res = createMockRes();

    errorHandler(err, req, res, () => {});

    assert.strictEqual(res.statusCode, 500);
    assert.strictEqual(res.body.success, false);
    assert.strictEqual(res.body.message, 'Internal server error');
  });
});

