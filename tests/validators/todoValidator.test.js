const { describe, it } = require('node:test');
const assert = require('node:assert');
const {
  createTodoSchema,
  updateTodoSchema,
  objectIdParamSchema,
} = require('../../src/validators/todoValidator');

describe('Todo Validators', () => {
  describe('createTodoSchema', () => {
    it('passes with valid title and description', () => {
      const result = createTodoSchema.safeParse({
        title: 'Buy groceries',
        description: 'Milk, eggs, bread',
      });
      assert.strictEqual(result.success, true);
      assert.strictEqual(result.data.title, 'Buy groceries');
    });

    it('trims whitespace on title and description', () => {
      const result = createTodoSchema.safeParse({
        title: '   Trimmed Title   ',
        description: '   Trimmed Desc   ',
      });
      assert.strictEqual(result.success, true);
      assert.strictEqual(result.data.title, 'Trimmed Title');
      assert.strictEqual(result.data.description, 'Trimmed Desc');
    });

    it('fails when title is missing or empty', () => {
      const emptyResult = createTodoSchema.safeParse({ title: '   ' });
      assert.strictEqual(emptyResult.success, false);

      const missingResult = createTodoSchema.safeParse({});
      assert.strictEqual(missingResult.success, false);
    });

    it('fails when title exceeds 200 characters', () => {
      const result = createTodoSchema.safeParse({ title: 'a'.repeat(201) });
      assert.strictEqual(result.success, false);
    });

    it('fails when extra unknown properties are provided (strict mode)', () => {
      const result = createTodoSchema.safeParse({
        title: 'Valid',
        unauthorizedField: 'hack',
      });
      assert.strictEqual(result.success, false);
    });
  });

  describe('updateTodoSchema', () => {
    it('passes with partial valid fields', () => {
      const result = updateTodoSchema.safeParse({ completed: true });
      assert.strictEqual(result.success, true);
      assert.strictEqual(result.data.completed, true);
    });

    it('fails when empty object is passed', () => {
      const result = updateTodoSchema.safeParse({});
      assert.strictEqual(result.success, false);
    });

    it('fails when completed is not a boolean', () => {
      const result = updateTodoSchema.safeParse({ completed: 'yes' });
      assert.strictEqual(result.success, false);
    });

    it('fails when extra unknown fields are passed', () => {
      const result = updateTodoSchema.safeParse({ completed: true, malicious: 123 });
      assert.strictEqual(result.success, false);
    });
  });

  describe('objectIdParamSchema', () => {
    it('passes with valid 24-char hex id', () => {
      const result = objectIdParamSchema.safeParse({ id: '507f1f77bcf86cd799439011' });
      assert.strictEqual(result.success, true);
    });

    it('fails with invalid id format', () => {
      const result = objectIdParamSchema.safeParse({ id: 'not-an-id' });
      assert.strictEqual(result.success, false);
    });
  });
});

