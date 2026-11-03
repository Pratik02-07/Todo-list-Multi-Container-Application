
const test = require('node:test');
const assert = require('node:assert/strict');

const {
  createTodoSchema,
  updateTodoSchema,
  objectIdParamSchema,
} = require('../backend/src/validators/todoValidator');

// CREATE TODO TESTS

test('Create Todo: accepts a valid title', () => {
  const result = createTodoSchema.safeParse({
    title: 'Learn Kubernetes',
  });

  assert.equal(result.success, true);
  assert.equal(result.data.title, 'Learn Kubernetes');
});

test('Create Todo: trims whitespace from title', () => {
  const result = createTodoSchema.safeParse({
    title: '  Learn Docker  ',
  });

  assert.equal(result.success, true);
  assert.equal(result.data.title, 'Learn Docker');
});

test('Create Todo: accepts optional description', () => {
  const result = createTodoSchema.safeParse({
    title: 'Learn AWS',
    description: 'Study AWS EKS and Terraform',
  });

  assert.equal(result.success, true);
});

test('Create Todo: rejects missing title', () => {
  const result = createTodoSchema.safeParse({});

  assert.equal(result.success, false);
});

test('Create Todo: rejects empty title', () => {
  const result = createTodoSchema.safeParse({
    title: '   ',
  });

  assert.equal(result.success, false);
});

test('Create Todo: rejects title exceeding 200 characters', () => {
  const result = createTodoSchema.safeParse({
    title: 'A'.repeat(201),
  });

  assert.equal(result.success, false);
});

test('Create Todo: rejects unknown fields', () => {
  const result = createTodoSchema.safeParse({
    title: 'Learn Kubernetes',
    admin: true,
  });

  assert.equal(result.success, false);
});

// UPDATE TODO TESTS

test('Update Todo: accepts a valid completed field', () => {
  const result = updateTodoSchema.safeParse({
    completed: true,
  });

  assert.equal(result.success, true);
});

test('Update Todo: accepts a valid title update', () => {
  const result = updateTodoSchema.safeParse({
    title: 'Updated Todo',
  });

  assert.equal(result.success, true);
});

test('Update Todo: rejects non-boolean completed value', () => {
  const result = updateTodoSchema.safeParse({
    completed: 'true',
  });

  assert.equal(result.success, false);
});

test('Update Todo: rejects an empty update object', () => {
  const result = updateTodoSchema.safeParse({});

  assert.equal(result.success, false);
});

test('Update Todo: rejects unknown fields', () => {
  const result = updateTodoSchema.safeParse({
    completed: true,
    admin: true,
  });

  assert.equal(result.success, false);
});

// OBJECT ID TESTS

test('Todo ID: accepts a valid MongoDB ObjectId', () => {
  const result = objectIdParamSchema.safeParse({
    id: '6aea2448c103c5c934c19033',
  });

  assert.equal(result.success, true);
});

test('Todo ID: rejects an invalid ObjectId', () => {
  const result = objectIdParamSchema.safeParse({
    id: 'invalid-id',
  });

  assert.equal(result.success, false);
});

test('Todo ID: rejects an ID with incorrect length', () => {
  const result = objectIdParamSchema.safeParse({
    id: '1234567890',
  });

  assert.equal(result.success, false);
});
