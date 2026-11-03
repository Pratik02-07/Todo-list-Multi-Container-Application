# API Validation, Nginx Reverse Proxy, and Persistence Testing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement strict request validation using Zod, centralized error handling in Express, a hardened Nginx reverse proxy configuration, and an automated persistence and container recovery verification suite.

**Architecture:** Express application enforces schema validation at route entry via Zod middleware and catches errors in a centralized error-handling middleware. Nginx serves as the single public gateway on port 80 forwarding requests to the private Node.js container, and a verification script tests end-to-end API correctness, Docker container restart recovery, and MongoDB named volume data persistence across lifecycle events.

**Tech Stack:** Node.js (v18+), Express, Mongoose, Zod, Nginx (Alpine), Docker Compose, `node:test` / `node:assert`.

**Spec:** `docs/superpowers/specs/2026-11-03-api-validation-nginx-persistence-design.md`

## Global Constraints
- Validation must be performed using `zod`.
- Error responses must be structured consistently with `{ success: false, message: string, errors?: array }`.
- Only Nginx port 80 may be exposed to the host; Node.js app must not publish host ports in Docker Compose.
- Nginx must configure a 1MB client body limit (`client_max_body_size 1m`) and standard security headers.
- Persistence testing must verify that MongoDB data in `mongo_data` survives `docker compose down` and recovery on container restart.
- Test runner uses Node's native `node:test` and `node:assert`.

---

### Task 1: Install Zod and Define Zod Schemas

**Files:**
- Modify: `package.json`
- Create: `tests/validators/todoValidator.test.js`
- Create: `src/validators/todoValidator.js`

**Interfaces:**
- Produces:
  - `createTodoSchema`: Zod schema for POST `/api/todos` body.
  - `updateTodoSchema`: Zod schema for PUT `/api/todos/:id` body.
  - `objectIdParamSchema`: Zod schema for `:id` route parameter.

- [ ] **Step 1: Install Zod and add test script to package.json**

Run:
```bash
npm install zod
```
And add `"test": "node --test tests/**/*.test.js"` to `"scripts"` in `package.json`.

- [ ] **Step 2: Write the failing unit tests for Todo validation schemas**

Create `tests/validators/todoValidator.test.js`:
```javascript
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
```

- [ ] **Step 3: Run validator tests to verify failure**

Run:
```bash
node --test tests/validators/todoValidator.test.js
```
Expected: FAIL (Cannot find module `../../src/validators/todoValidator`).

- [ ] **Step 4: Implement Zod schemas in `src/validators/todoValidator.js`**

Create `src/validators/todoValidator.js`:
```javascript
const { z } = require('zod');

const createTodoSchema = z
  .object({
    title: z
      .string({ required_error: 'Title is required' })
      .trim()
      .min(1, 'Title cannot be empty')
      .max(200, 'Title cannot exceed 200 characters'),
    description: z
      .string()
      .trim()
      .max(1000, 'Description cannot exceed 1000 characters')
      .optional(),
  })
  .strict({ message: 'Unrecognized fields in request body' });

const updateTodoSchema = z
  .object({
    title: z
      .string()
      .trim()
      .min(1, 'Title cannot be empty')
      .max(200, 'Title cannot exceed 200 characters')
      .optional(),
    description: z
      .string()
      .trim()
      .max(1000, 'Description cannot exceed 1000 characters')
      .optional(),
    completed: z
      .boolean({ invalid_type_error: 'Completed must be a boolean' })
      .optional(),
  })
  .strict({ message: 'Unrecognized fields in request body' })
  .refine(
    (data) => Object.keys(data).length > 0,
    { message: 'At least one field must be provided for update' }
  );

const objectIdParamSchema = z.object({
  id: z
    .string({ required_error: 'ID is required' })
    .regex(/^[0-9a-fA-F]{24}$/, 'Invalid Todo ID format (must be a 24-character hexadecimal string)'),
});

module.exports = {
  createTodoSchema,
  updateTodoSchema,
  objectIdParamSchema,
};
```

- [ ] **Step 5: Run validator tests to verify they pass**

Run:
```bash
node --test tests/validators/todoValidator.test.js
```
Expected: PASS.

- [ ] **Step 6: Commit Task 1**

```bash
git add package.json package-lock.json src/validators/todoValidator.js tests/validators/todoValidator.test.js
git commit -m "feat: add Zod validation schemas and unit tests for todos"
```

---

### Task 2: Implement Generic Validation Middleware

**Files:**
- Create: `tests/middlewares/validate.test.js`
- Create: `src/middlewares/validate.js`

**Interfaces:**
- Consumes: Zod schemas.
- Produces: `validate({ body, params, query })` Express middleware.

- [ ] **Step 1: Write failing tests for validation middleware**

Create `tests/middlewares/validate.test.js`:
```javascript
const { describe, it } = require('node:test');
const assert = require('node:assert');
const { z } = require('zod');
const validate = require('../../src/middlewares/validate');

describe('validate middleware', () => {
  it('calls next() and updates req data with parsed output when valid', () => {
    const middleware = validate({
      body: z.object({ title: z.string().trim() }),
    });

    const req = { body: { title: '  hello  ' } };
    const res = {};
    let nextCalled = false;

    middleware(req, res, (err) => {
      assert.strictEqual(err, undefined);
      nextCalled = true;
    });

    assert.strictEqual(nextCalled, true);
    assert.strictEqual(req.body.title, 'hello');
  });

  it('responds with 400 and structured errors when validation fails', () => {
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
      },
    };

    middleware(req, res, () => {
      assert.fail('next() should not be called when validation fails');
    });

    assert.strictEqual(statusCode, 400);
    assert.strictEqual(jsonPayload.success, false);
    assert.strictEqual(jsonPayload.message, 'Validation failed');
    assert.strictEqual(Array.isArray(jsonPayload.errors), true);
    assert.strictEqual(jsonPayload.errors[0].field, 'title');
  });
});
```

- [ ] **Step 2: Run test to verify failure**

Run:
```bash
node --test tests/middlewares/validate.test.js
```
Expected: FAIL (Cannot find module `../../src/middlewares/validate`).

- [ ] **Step 3: Implement `src/middlewares/validate.js`**

Create `src/middlewares/validate.js`:
```javascript
/**
 * Generic Express validation middleware using Zod schemas.
 * @param {Object} schemas - Schema mapping for body, params, and/or query.
 * @param {import('zod').ZodSchema} [schemas.body]
 * @param {import('zod').ZodSchema} [schemas.params]
 * @param {import('zod').ZodSchema} [schemas.query]
 */
const validate = (schemas) => (req, res, next) => {
  const errors = [];

  ['params', 'query', 'body'].forEach((location) => {
    if (schemas[location]) {
      const result = schemas[location].safeParse(req[location]);
      if (!result.success) {
        result.error.errors.forEach((err) => {
          errors.push({
            location,
            field: err.path.join('.') || location,
            message: err.message,
          });
        });
      } else {
        req[location] = result.data;
      }
    }
  });

  if (errors.length > 0) {
    return res.status(400).json({
      success: false,
      message: 'Validation failed',
      errors,
    });
  }

  next();
};

module.exports = validate;
```

- [ ] **Step 4: Run test to verify it passes**

Run:
```bash
node --test tests/middlewares/validate.test.js
```
Expected: PASS.

- [ ] **Step 5: Commit Task 2**

```bash
git add src/middlewares/validate.js tests/middlewares/validate.test.js
git commit -m "feat: implement generic Zod validation middleware"
```

---

### Task 3: Centralized Error Handler and AppError

**Files:**
- Create: `src/utils/AppError.js`
- Create: `tests/middlewares/errorHandler.test.js`
- Create: `src/middlewares/errorHandler.js`

**Interfaces:**
- Produces: `AppError` class and `errorHandler` Express middleware.

- [ ] **Step 1: Create `src/utils/AppError.js`**

Create `src/utils/AppError.js`:
```javascript
class AppError extends Error {
  constructor(message, statusCode = 500) {
    super(message);
    this.statusCode = statusCode;
    this.isOperational = true;
    Error.captureStackTrace(this, this.constructor);
  }
}

module.exports = AppError;
```

- [ ] **Step 2: Write failing tests for `errorHandler` middleware**

Create `tests/middlewares/errorHandler.test.js`:
```javascript
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

  it('handles malformed JSON SyntaxError', () => {
    const err = new SyntaxError('Unexpected token in JSON');
    err.status = 400;
    const req = {};
    const res = createMockRes();

    errorHandler(err, req, res, () => {});

    assert.strictEqual(res.statusCode, 400);
    assert.strictEqual(res.body.success, false);
    assert.strictEqual(res.body.message, 'Invalid JSON format in request body');
  });

  it('handles Mongoose CastError', () => {
    const err = new Error('Cast to ObjectId failed for value "badId"');
    err.name = 'CastError';
    err.value = 'badId';
    const req = {};
    const res = createMockRes();

    errorHandler(err, req, res, () => {});

    assert.strictEqual(res.statusCode, 400);
    assert.strictEqual(res.body.success, false);
    assert.strictEqual(res.body.message, 'Invalid ID format: badId');
  });

  it('handles generic unhandled error with 500', () => {
    const err = new Error('Database crash');
    const req = {};
    const res = createMockRes();

    errorHandler(err, req, res, () => {});

    assert.strictEqual(res.statusCode, 500);
    assert.strictEqual(res.body.success, false);
    assert.strictEqual(res.body.message, 'Internal server error');
  });
});
```

- [ ] **Step 3: Run test to verify failure**

Run:
```bash
node --test tests/middlewares/errorHandler.test.js
```
Expected: FAIL (Cannot find module `../../src/middlewares/errorHandler`).

- [ ] **Step 4: Implement `src/middlewares/errorHandler.js`**

Create `src/middlewares/errorHandler.js`:
```javascript
/**
 * Centralized global error handling middleware.
 */
const errorHandler = (err, req, res, next) => {
  let statusCode = err.statusCode || err.status || 500;
  let message = err.message || 'Internal server error';
  let errors = err.errors;

  // Handle malformed JSON body parsed by express.json()
  if (err instanceof SyntaxError && err.status === 400 && 'body' in err) {
    statusCode = 400;
    message = 'Invalid JSON format in request body';
  }

  // Handle Mongoose CastError (invalid ObjectId)
  if (err.name === 'CastError') {
    statusCode = 400;
    message = `Invalid ID format: ${err.value}`;
  }

  // Handle Mongoose ValidationError
  if (err.name === 'ValidationError') {
    statusCode = 400;
    message = 'Validation failed';
    errors = Object.values(err.errors).map((e) => ({
      field: e.path,
      message: e.message,
    }));
  }

  // Hide 500 internal details in production
  if (statusCode === 500 && process.env.NODE_ENV === 'production') {
    message = 'Internal server error';
  }

  if (statusCode === 500) {
    console.error('Unhandled Application Error:', err);
  }

  const response = {
    success: false,
    message,
  };

  if (errors && errors.length > 0) {
    response.errors = errors;
  }

  res.status(statusCode).json(response);
};

module.exports = errorHandler;
```

- [ ] **Step 5: Run test to verify it passes**

Run:
```bash
node --test tests/middlewares/errorHandler.test.js
```
Expected: PASS.

- [ ] **Step 6: Commit Task 3**

```bash
git add src/utils/AppError.js src/middlewares/errorHandler.js tests/middlewares/errorHandler.test.js
git commit -m "feat: implement centralized error handler and AppError utility"
```

---

### Task 4: Integrate Validation & Error Handling into Routes and Controller

**Files:**
- Modify: `src/routes/todoRoutes.js`
- Modify: `src/controllers/todoController.js`
- Modify: `src/server.js`
- Create: `tests/integration/todoRoutes.test.js`

**Interfaces:**
- Consumes: `validate`, schemas, `errorHandler`, `AppError`.
- Produces: Fully validated `/api/todos` CRUD endpoints.

- [ ] **Step 1: Write integration tests for API validation and error handling**

Create `tests/integration/todoRoutes.test.js`:
```javascript
const { describe, it } = require('node:test');
const assert = require('node:assert');
const app = require('../../src/server');

// Helper to make lightweight HTTP requests directly against Express app
const testRequest = (app) => {
  const http = require('http');
  const server = http.createServer(app);

  return {
    async request(method, path, body = null) {
      return new Promise((resolve, reject) => {
        server.listen(0, '127.0.0.1', () => {
          const port = server.address().port;
          const payload = body ? JSON.stringify(body) : null;
          const req = http.request(
            {
              hostname: '127.0.0.1',
              port,
              path,
              method,
              headers: {
                'Content-Type': 'application/json',
                ...(payload ? { 'Content-Length': Buffer.byteLength(payload) } : {}),
              },
            },
            (res) => {
              let data = '';
              res.on('data', (chunk) => (data += chunk));
              res.on('end', () => {
                server.close();
                try {
                  resolve({
                    status: res.statusCode,
                    headers: res.headers,
                    body: data ? JSON.parse(data) : null,
                  });
                } catch {
                  resolve({ status: res.statusCode, headers: res.headers, body: data });
                }
              });
            }
          );
          req.on('error', (err) => {
            server.close();
            reject(err);
          });
          if (payload) req.write(payload);
          req.end();
        });
      });
    },
  };
};

describe('Todo API Validation & Routing Integration', () => {
  const client = testRequest(app);

  it('rejects POST /api/todos with missing title (400)', async () => {
    const res = await client.request('POST', '/api/todos', { description: 'Missing title' });
    assert.strictEqual(res.status, 400);
    assert.strictEqual(res.body.success, false);
    assert.strictEqual(res.body.message, 'Validation failed');
    assert.strictEqual(res.body.errors.some((e) => e.field === 'title'), true);
  });

  it('rejects POST /api/todos with extra unallowed fields (400)', async () => {
    const res = await client.request('POST', '/api/todos', {
      title: 'Valid title',
      extraField: 'should fail',
    });
    assert.strictEqual(res.status, 400);
    assert.strictEqual(res.body.success, false);
  });

  it('rejects GET /api/todos/:id with malformed id (400)', async () => {
    const res = await client.request('GET', '/api/todos/not-a-valid-id');
    assert.strictEqual(res.status, 400);
    assert.strictEqual(res.body.success, false);
    assert.strictEqual(res.body.errors.some((e) => e.field === 'id'), true);
  });

  it('rejects PUT /api/todos/:id with empty update object (400)', async () => {
    const res = await client.request('PUT', '/api/todos/507f1f77bcf86cd799439011', {});
    assert.strictEqual(res.status, 400);
    assert.strictEqual(res.body.success, false);
  });

  it('returns 404 for non-existent route', async () => {
    const res = await client.request('GET', '/api/non-existent-route');
    assert.strictEqual(res.status, 404);
    assert.strictEqual(res.body.success, false);
  });
});
```

- [ ] **Step 2: Update `src/routes/todoRoutes.js` with validation middleware**

Modify `src/routes/todoRoutes.js`:
```javascript
const express = require('express');
const router = express.Router();
const validate = require('../middlewares/validate');
const {
  createTodoSchema,
  updateTodoSchema,
  objectIdParamSchema,
} = require('../validators/todoValidator');
const {
  getAllTodos,
  getTodoById,
  createTodo,
  updateTodo,
  deleteTodo,
} = require('../controllers/todoController');

// GET  /api/todos       — list all todos
// POST /api/todos       — create a new todo with body validation
router
  .route('/')
  .get(getAllTodos)
  .post(validate({ body: createTodoSchema }), createTodo);

// GET    /api/todos/:id — get a single todo with id validation
// PUT    /api/todos/:id — update a todo with id and body validation
// DELETE /api/todos/:id — delete a todo with id validation
router
  .route('/:id')
  .get(validate({ params: objectIdParamSchema }), getTodoById)
  .put(validate({ params: objectIdParamSchema, body: updateTodoSchema }), updateTodo)
  .delete(validate({ params: objectIdParamSchema }), deleteTodo);

module.exports = router;
```

- [ ] **Step 3: Update `src/controllers/todoController.js` to delegate errors to `next()`**

Modify `src/controllers/todoController.js`:
```javascript
const Todo = require('../models/Todo');
const AppError = require('../utils/AppError');

/**
 * @desc    Get all todos
 * @route   GET /api/todos
 * @access  Public
 */
const getAllTodos = async (req, res, next) => {
  try {
    const todos = await Todo.find().sort({ createdAt: -1 });
    res.status(200).json({ success: true, count: todos.length, data: todos });
  } catch (error) {
    next(error);
  }
};

/**
 * @desc    Get a single todo by ID
 * @route   GET /api/todos/:id
 * @access  Public
 */
const getTodoById = async (req, res, next) => {
  try {
    const todo = await Todo.findById(req.params.id);
    if (!todo) {
      return next(new AppError('Todo not found', 404));
    }
    res.status(200).json({ success: true, data: todo });
  } catch (error) {
    next(error);
  }
};

/**
 * @desc    Create a new todo
 * @route   POST /api/todos
 * @access  Public
 */
const createTodo = async (req, res, next) => {
  try {
    const { title, description } = req.body;
    const todo = await Todo.create({ title, description });
    res.status(201).json({ success: true, data: todo });
  } catch (error) {
    next(error);
  }
};

/**
 * @desc    Update a todo by ID
 * @route   PUT /api/todos/:id
 * @access  Public
 */
const updateTodo = async (req, res, next) => {
  try {
    const todo = await Todo.findByIdAndUpdate(
      req.params.id,
      req.body,
      { new: true, runValidators: true }
    );
    if (!todo) {
      return next(new AppError('Todo not found', 404));
    }
    res.status(200).json({ success: true, data: todo });
  } catch (error) {
    next(error);
  }
};

/**
 * @desc    Delete a todo by ID
 * @route   DELETE /api/todos/:id
 * @access  Public
 */
const deleteTodo = async (req, res, next) => {
  try {
    const todo = await Todo.findByIdAndDelete(req.params.id);
    if (!todo) {
      return next(new AppError('Todo not found', 404));
    }
    res.status(200).json({ success: true, message: 'Todo deleted successfully' });
  } catch (error) {
    next(error);
  }
};

module.exports = { getAllTodos, getTodoById, createTodo, updateTodo, deleteTodo };
```

- [ ] **Step 4: Update `src/server.js` to wire in `errorHandler`**

Modify `src/server.js`:
```javascript
require('dotenv').config();
const express = require('express');
const connectDB = require('./config/db');
const todoRoutes = require('./routes/todoRoutes');
const errorHandler = require('./middlewares/errorHandler');

const app = express();
const PORT = process.env.PORT || 3000;

// ─── Middleware ───────────────────────────────────────────────────────────────
app.use(express.json());
app.use(express.urlencoded({ extended: false }));

// ─── Routes ───────────────────────────────────────────────────────────────────
app.get('/health', (req, res) => {
  res.status(200).json({ status: 'ok', uptime: process.uptime() });
});

app.use('/api/todos', todoRoutes);

// ─── 404 Handler ─────────────────────────────────────────────────────────────
app.use((req, res) => {
  res.status(404).json({ success: false, message: `Route not found: ${req.method} ${req.originalUrl}` });
});

// ─── Global Centralized Error Handler ────────────────────────────────────────
app.use(errorHandler);

// ─── Start Server ─────────────────────────────────────────────────────────────
const startServer = async () => {
  try {
    await connectDB();
    app.listen(PORT, '0.0.0.0', () => {
      console.log(`Server running on port ${PORT}`);
    });
  } catch (error) {
    console.error('Application startup failed:', error);
    process.exit(1);
  }
};

if (require.main === module) {
  startServer();
}

module.exports = app;
```

- [ ] **Step 5: Run all unit and integration tests**

Run:
```bash
npm test
```
Expected: All tests PASS.

- [ ] **Step 6: Commit Task 4**

```bash
git add src/routes/todoRoutes.js src/controllers/todoController.js src/server.js tests/integration/todoRoutes.test.js
git commit -m "feat: wire Zod validation and centralized error handling into Express app"
```

---

### Task 5: Enhance and Verify Nginx Reverse Proxy Configuration

**Files:**
- Modify: `nginx/nginx.conf`
- Modify: `docker-compose.yml`

**Interfaces:**
- Produces: Nginx reverse proxy running on port 80 proxying to Node.js app with security headers and client body limits.

- [ ] **Step 1: Update `nginx/nginx.conf` with security headers and body limit**

Update `nginx/nginx.conf`:
```nginx
upstream app {
    server app:3000;
    keepalive 16;
}

server {
    listen 80;
    server_name _;

    # Maximum client request body size (1MB limit)
    client_max_body_size 1m;

    # Security Headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    # Proxy /api requests to the Node.js app container
    location /api {
        proxy_pass         http://app;
        proxy_http_version 1.1;

        proxy_set_header   Connection        "";
        proxy_set_header   Host              $host;
        proxy_set_header   X-Real-IP         $remote_addr;
        proxy_set_header   X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto $scheme;

        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout    60s;
        proxy_read_timeout    60s;
    }

    # Health-check endpoint proxied to the app
    location /health {
        proxy_pass         http://app;
        proxy_http_version 1.1;
        proxy_set_header   Host $host;
    }

    # Return 404 JSON for any other non-proxied paths
    location / {
        return 404 '{"success":false,"message":"Not Found"}';
        add_header Content-Type application/json;
    }
}
```

- [ ] **Step 2: Verify `docker-compose.yml` network isolation and port bindings**

Verify in `docker-compose.yml` that:
1. `app` has NO host port bindings (internal only on port 3000).
2. `nginx` has `ports: - "80:80"`.
3. `mongo` has `volumes: - mongo_data:/data/db` and healthcheck configured.

- [ ] **Step 3: Test Docker Compose build and start**

Run:
```bash
docker compose build
docker compose up -d
```
Expected: All 3 containers (`todo_mongo`, `todo_app`, `todo_nginx`) start healthy and running.

- [ ] **Step 4: Verify Nginx proxying and security headers via HTTP request**

Run:
```bash
curl -i http://localhost/health
```
Expected: HTTP/1.1 200 OK, `x-content-type-options: nosniff`, `x-frame-options: SAMEORIGIN`, body `{"status":"ok",...}`.

- [ ] **Step 5: Commit Task 5**

```bash
git add nginx/nginx.conf docker-compose.yml
git commit -m "feat: enhance Nginx reverse proxy configuration with security headers and limits"
```

---

### Task 6: Implement Automated Persistence and Recovery Test Script & Execute Verification

**Files:**
- Create: `scripts/verify-persistence-recovery.js`
- Modify: `README.md`

**Interfaces:**
- Produces: Executable Node.js test script `node scripts/verify-persistence-recovery.js` verifying CRUD, validation, container recovery, and MongoDB volume persistence across restarts.

- [ ] **Step 1: Write `scripts/verify-persistence-recovery.js`**

Create `scripts/verify-persistence-recovery.js`:
```javascript
const http = require('http');
const { execSync } = require('child_process');

const BASE_URL = 'http://localhost';

const request = (method, path, body = null) => {
  return new Promise((resolve, reject) => {
    const payload = body ? JSON.stringify(body) : null;
    const req = http.request(
      `${BASE_URL}${path}`,
      {
        method,
        headers: {
          'Content-Type': 'application/json',
          ...(payload ? { 'Content-Length': Buffer.byteLength(payload) } : {}),
        },
      },
      (res) => {
        let data = '';
        res.on('data', (chunk) => (data += chunk));
        res.on('end', () => {
          try {
            resolve({
              statusCode: res.statusCode,
              headers: res.headers,
              body: data ? JSON.parse(data) : null,
            });
          } catch {
            resolve({ statusCode: res.statusCode, headers: res.headers, body: data });
          }
        });
      }
    );
    req.on('error', reject);
    if (payload) req.write(payload);
    req.end();
  });
};

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

async function runVerification() {
  console.log('====================================================');
  console.log(' Starting Persistence and Container Recovery Tests  ');
  console.log('====================================================\n');

  // 1. Health check via Nginx
  console.log('1. Checking Nginx proxy and application health...');
  const healthRes = await request('GET', '/health');
  if (healthRes.statusCode !== 200 || healthRes.body?.status !== 'ok') {
    throw new Error(`Health check failed: ${JSON.stringify(healthRes)}`);
  }
  console.log('   [PASS] Health check returned 200 OK through Nginx.\n');

  // 2. Validate API Error Handling through Nginx
  console.log('2. Testing API Validation & Error Handling through Nginx...');
  const invalidCreate = await request('POST', '/api/todos', {});
  if (invalidCreate.statusCode !== 400 || !invalidCreate.body?.errors) {
    throw new Error(`Validation failed to reject empty body: ${JSON.stringify(invalidCreate)}`);
  }
  console.log('   [PASS] POST /api/todos with empty body rejected with 400 Bad Request.');

  const invalidId = await request('GET', '/api/todos/123-bad-id');
  if (invalidId.statusCode !== 400) {
    throw new Error(`Validation failed to reject malformed ID: ${JSON.stringify(invalidId)}`);
  }
  console.log('   [PASS] GET /api/todos/123-bad-id rejected with 400 Bad Request.\n');

  // 3. Create persistent record
  const uniqueTitle = `PERSISTENCE_TEST_${Date.now()}`;
  console.log(`3. Creating persistence test item: "${uniqueTitle}"...`);
  const createRes = await request('POST', '/api/todos', {
    title: uniqueTitle,
    description: 'Verifying data persistence across container restarts and recreations',
  });
  if (createRes.statusCode !== 201 || !createRes.body?.data?._id) {
    throw new Error(`Failed to create Todo: ${JSON.stringify(createRes)}`);
  }
  const todoId = createRes.body.data._id;
  console.log(`   [PASS] Created Todo with ID: ${todoId}\n`);

  // 4. Test Container Recovery (Restarting containers)
  console.log('4. Testing Container Recovery (restarting todo_app)...');
  execSync('docker restart todo_app', { stdio: 'inherit' });
  console.log('   Waiting for todo_app to recover...');
  let recovered = false;
  for (let i = 0; i < 15; i++) {
    await sleep(1000);
    try {
      const ping = await request('GET', '/health');
      if (ping.statusCode === 200) {
        recovered = true;
        break;
      }
    } catch {}
  }
  if (!recovered) throw new Error('todo_app container failed to recover within 15s');
  console.log('   [PASS] todo_app recovered successfully.\n');

  // 5. Test Volume Persistence across docker compose down & up
  console.log('5. Testing Volume Persistence across docker compose down and up...');
  console.log('   Executing docker compose down (preserving volumes)...');
  execSync('docker compose down', { stdio: 'inherit' });
  console.log('   Executing docker compose up -d...');
  execSync('docker compose up -d', { stdio: 'inherit' });

  console.log('   Waiting for services and MongoDB health...');
  let apiReady = false;
  for (let i = 0; i < 20; i++) {
    await sleep(1500);
    try {
      const check = await request('GET', '/api/todos');
      if (check.statusCode === 200 && Array.isArray(check.body?.data)) {
        apiReady = true;
        break;
      }
    } catch {}
  }
  if (!apiReady) throw new Error('API did not become ready after docker compose up');

  // Verify persistence of the item
  console.log('   Querying Todos to verify item persisted...');
  const listRes = await request('GET', '/api/todos');
  const found = listRes.body.data.find((item) => item._id === todoId);
  if (!found || found.title !== uniqueTitle) {
    throw new Error(`Persistence failure: Todo ${todoId} was not found in database!`);
  }
  console.log(`   [PASS] Volume Persistence Verified! Item "${found.title}" retained successfully.\n`);

  // 6. Cleanup test record
  console.log('6. Cleaning up test record...');
  const deleteRes = await request('DELETE', `/api/todos/${todoId}`);
  if (deleteRes.statusCode !== 200) {
    throw new Error(`Cleanup deletion failed: ${JSON.stringify(deleteRes)}`);
  }
  console.log('   [PASS] Cleaned up test item successfully.\n');

  console.log('====================================================');
  console.log(' ALL PERSISTENCE & RECOVERY TESTS PASSED!           ');
  console.log('====================================================');
}

runVerification().catch((err) => {
  console.error('\nVerification failed:', err);
  process.exit(1);
});
```

- [ ] **Step 2: Update `README.md` with persistence and recovery test commands**

Add a dedicated testing section to `README.md` documenting:
- Running unit and integration tests: `npm test`
- Running full multi-container persistence & recovery verification: `node scripts/verify-persistence-recovery.js`
- Explanation of volume persistence and container recovery behavior.

- [ ] **Step 3: Run the automated verification script**

Run:
```bash
node scripts/verify-persistence-recovery.js
```
Expected:
- Health check returns 200 OK through Nginx.
- API validation and rejection tests pass.
- Container restart recovery passes.
- Volume persistence across `docker compose down` and `docker compose up -d` passes.
- Cleanup succeeds.

- [ ] **Step 4: Commit Task 6**

```bash
git add scripts/verify-persistence-recovery.js README.md
git commit -m "test: add automated persistence and container recovery verification script and documentation"
```
