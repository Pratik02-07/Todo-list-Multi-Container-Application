# Sub-Project 1: Core API & Static Web UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Complete the backend API validation and centralized error handling, expose live deployment metadata, build a responsive static web UI with an active Blue/Green environment badge, and configure Nginx to serve the UI and proxy the API.

**Architecture:** Node.js Express API enforces input validation using Zod middleware, processes CRUD in controllers, formats errors uniformly with centralized error middleware, and exposes `APP_VERSION` and `APP_COLOR` on `/health`. Nginx acts as the single public gateway on port 80, delivering static frontend files directly from `/usr/share/nginx/html` and reverse proxying `/api` and `/health` to the internal Node.js container.

**Tech Stack:** Node.js, Express, Mongoose, Zod, Nginx (Alpine), HTML5, CSS3, Vanilla ES6 JavaScript, `node:test` / `node:assert`.

**Spec:** `docs/superpowers/specs/2026-11-03-subproject-1-api-and-static-ui-design.md`

## Global Constraints
- Work directly in the repository on main (user instructed no branching).
- Tests must use built-in `node:test` and `node:assert`.
- Error responses must strictly adhere to `{ success: false, message: string, errors?: array }`.
- Deployment metadata (`version`, `color`) must be exposed via `/health` reading `APP_VERSION` and `APP_COLOR`.
- Nginx must serve static assets from `/usr/share/nginx/html` and proxy `/api` and `/health` to `http://app:3000`.
- The static web UI must be pure HTML/CSS/vanilla JS with no external runtime CDN dependencies.

---

### Task 1: Complete and Verify Generic Validation Middleware

**Files:**
- Create: `tests/middlewares/validate.test.js`
- Create: `src/middlewares/validate.js`

**Interfaces:**
- Consumes: Zod schemas from `src/validators/todoValidator.js`.
- Produces: `validate({ body, params, query })` higher-order Express middleware.

- [ ] **Step 1: Write failing unit test for validation middleware**

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
```

- [ ] **Step 2: Run test to verify it fails**

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
 * @param {Object} schemas
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
Expected: PASS (2 tests pass).

- [ ] **Step 5: Commit Task 1**

```bash
git add src/middlewares/validate.js tests/middlewares/validate.test.js
git commit -m "feat: implement generic Zod validation middleware"
```

---

### Task 2: Implement Centralized Error Handler and AppError

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

- [ ] **Step 2: Write failing unit tests for `errorHandler`**

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
```

- [ ] **Step 3: Run test to verify it fails**

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
Expected: PASS (4 tests pass).

- [ ] **Step 6: Commit Task 2**

```bash
git add src/utils/AppError.js src/middlewares/errorHandler.js tests/middlewares/errorHandler.test.js
git commit -m "feat: implement centralized error handler and AppError utility"
```

---

### Task 3: Wire Validation, Error Handler, and Deployment Metadata into Express App

**Files:**
- Modify: `src/routes/todoRoutes.js`
- Modify: `src/controllers/todoController.js`
- Modify: `src/server.js`
- Create: `tests/integration/todoRoutes.test.js`

**Interfaces:**
- Consumes: `validate`, Zod schemas, `errorHandler`, `AppError`.
- Produces: Validated `/api/todos` CRUD endpoints and `/health` with version/color metadata.

- [ ] **Step 1: Write integration tests for routes, validation, and `/health` metadata**

Create `tests/integration/todoRoutes.test.js`:
```javascript
const { describe, it } = require('node:test');
const assert = require('node:assert');
const http = require('http');
const app = require('../../src/server');

const testRequest = (app) => {
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

describe('API Routes & Validation Integration', () => {
  const client = testRequest(app);

  it('GET /health returns version, color, and status ok', async () => {
    const res = await client.request('GET', '/health');
    assert.strictEqual(res.status, 200);
    assert.strictEqual(res.body.status, 'ok');
    assert.strictEqual(typeof res.body.version, 'string');
    assert.strictEqual(typeof res.body.color, 'string');
  });

  it('rejects POST /api/todos with missing title (400)', async () => {
    const res = await client.request('POST', '/api/todos', { description: 'No title' });
    assert.strictEqual(res.status, 400);
    assert.strictEqual(res.body.success, false);
    assert.strictEqual(res.body.message, 'Validation failed');
    assert.strictEqual(res.body.errors.some((e) => e.field === 'title'), true);
  });

  it('rejects POST /api/todos with unrecognized property (400)', async () => {
    const res = await client.request('POST', '/api/todos', {
      title: 'Valid title',
      unauthorizedKey: 'value',
    });
    assert.strictEqual(res.status, 400);
    assert.strictEqual(res.body.success, false);
  });

  it('rejects GET /api/todos/:id with malformed id (400)', async () => {
    const res = await client.request('GET', '/api/todos/not-an-objectid');
    assert.strictEqual(res.status, 400);
    assert.strictEqual(res.body.success, false);
    assert.strictEqual(res.body.errors.some((e) => e.field === 'id'), true);
  });

  it('rejects PUT /api/todos/:id with empty body (400)', async () => {
    const res = await client.request('PUT', '/api/todos/507f1f77bcf86cd799439011', {});
    assert.strictEqual(res.status, 400);
    assert.strictEqual(res.body.success, false);
  });

  it('returns 404 for unknown route', async () => {
    const res = await client.request('GET', '/api/unknown-endpoint');
    assert.strictEqual(res.status, 404);
    assert.strictEqual(res.body.success, false);
  });
});
```

- [ ] **Step 2: Update `src/routes/todoRoutes.js`**

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

- [ ] **Step 3: Update `src/controllers/todoController.js` to delegate errors to `next(error)`**

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

- [ ] **Step 4: Update `src/server.js` with metadata `/health` and `errorHandler`**

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

// ─── Health & Deployment Metadata Route ───────────────────────────────────────
app.get('/health', (req, res) => {
  res.status(200).json({
    status: 'ok',
    version: process.env.APP_VERSION || '1.0.0',
    color: process.env.APP_COLOR || 'blue',
    uptime: process.uptime(),
    timestamp: new Date().toISOString(),
  });
});

// ─── API Routes ───────────────────────────────────────────────────────────────
app.use('/api/todos', todoRoutes);

// ─── 404 Handler ─────────────────────────────────────────────────────────────
app.use((req, res) => {
  res.status(404).json({
    success: false,
    message: `Route not found: ${req.method} ${req.originalUrl}`,
  });
});

// ─── Centralized Error Handler ───────────────────────────────────────────────
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

- [ ] **Step 5: Run all test suites**

Run:
```bash
npm test
```
Expected: PASS (all validator, middleware, and integration tests pass).

- [ ] **Step 6: Commit Task 3**

```bash
git add src/routes/todoRoutes.js src/controllers/todoController.js src/server.js tests/integration/todoRoutes.test.js
git commit -m "feat: integrate validation, centralized error handling, and deployment metadata into Express app"
```

---

### Task 4: Build the Static Web Frontend (HTML, CSS, JS)

**Files:**
- Create: `public/index.html`
- Create: `public/style.css`
- Create: `public/app.js`

**Interfaces:**
- Consumes: `/health` (deployment metadata: `version`, `color`) and `/api/todos` (CRUD API).
- Produces: Complete responsive UI served by Nginx with dynamic Blue/Green status badge.

- [ ] **Step 1: Create `public/index.html`**

Create `public/index.html`:
```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Todo List — Cloud Native App</title>
  <link rel="stylesheet" href="style.css">
</head>
<body>
  <div class="container">
    <header class="app-header">
      <div class="header-left">
        <h1>Cloud Todo List</h1>
        <p class="subtitle">Multi-Container Architecture with Zero-Downtime Deployment</p>
      </div>
      <div class="deployment-box">
        <span class="badge-title">Active Deployment</span>
        <span id="env-badge" class="badge badge-loading">Connecting...</span>
      </div>
    </header>

    <div id="error-alert" class="alert-banner hidden" role="alert"></div>

    <section class="card form-card">
      <h2>Add New Task</h2>
      <form id="todo-form">
        <div class="form-group">
          <label for="todo-title">Task Title *</label>
          <input
            type="text"
            id="todo-title"
            name="title"
            placeholder="What needs to be done?"
            required
            maxlength="200"
            autocomplete="off"
          />
        </div>
        <div class="form-group">
          <label for="todo-desc">Description (Optional)</label>
          <input
            type="text"
            id="todo-desc"
            name="description"
            placeholder="Add extra details..."
            maxlength="1000"
            autocomplete="off"
          />
        </div>
        <button type="submit" id="btn-add-todo" class="btn btn-primary">Add Task</button>
      </form>
    </section>

    <section class="card list-card">
      <div class="list-header">
        <h2>Your Tasks</h2>
        <div class="task-stats">
          <span class="stat-item">Total: <strong id="total-count">0</strong></span>
          <span class="stat-item">Completed: <strong id="completed-count">0</strong></span>
        </div>
      </div>
      <div id="todo-list" class="todo-list">
        <div class="loading-state">Loading tasks...</div>
      </div>
    </section>
  </div>

  <script src="app.js"></script>
</body>
</html>
```

- [ ] **Step 2: Create `public/style.css`**

Create `public/style.css`:
```css
:root {
  --bg-color: #0f172a;
  --card-bg: #1e293b;
  --text-main: #f8fafc;
  --text-muted: #94a3b8;
  --border-color: #334155;
  --primary-color: #3b82f6;
  --primary-hover: #2563eb;
  --danger-color: #ef4444;
  --danger-hover: #dc2626;
  --success-color: #10b981;
}

* {
  box-sizing: border-box;
  margin: 0;
  padding: 0;
}

body {
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
  background-color: var(--bg-color);
  color: var(--text-main);
  min-height: 100vh;
  padding: 2rem 1rem;
}

.container {
  max-width: 760px;
  margin: 0 auto;
}

/* Header & Deployment Badge */
.app-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  flex-wrap: wrap;
  gap: 1rem;
  margin-bottom: 2rem;
  padding-bottom: 1.5rem;
  border-bottom: 1px solid var(--border-color);
}

.app-header h1 {
  font-size: 1.75rem;
  font-weight: 700;
  color: #fff;
}

.subtitle {
  font-size: 0.9rem;
  color: var(--text-muted);
  margin-top: 0.25rem;
}

.deployment-box {
  display: flex;
  flex-direction: column;
  align-items: flex-end;
  gap: 0.25rem;
}

.badge-title {
  font-size: 0.75rem;
  text-transform: uppercase;
  letter-spacing: 0.05em;
  color: var(--text-muted);
}

.badge {
  display: inline-block;
  padding: 0.35rem 0.85rem;
  border-radius: 9999px;
  font-size: 0.85rem;
  font-weight: 600;
  letter-spacing: 0.02em;
  transition: all 0.2s ease;
}

.badge-loading {
  background-color: #334155;
  color: #cbd5e1;
}

/* Blue & Green themes for deployment */
.badge-blue {
  background-color: #1e3a8a;
  color: #93c5fd;
  border: 1px solid #3b82f6;
  box-shadow: 0 0 10px rgba(59, 130, 246, 0.3);
}

.badge-green {
  background-color: #064e3b;
  color: #6ee7b7;
  border: 1px solid #10b981;
  box-shadow: 0 0 10px rgba(16, 185, 129, 0.3);
}

/* Cards & Layout */
.card {
  background-color: var(--card-bg);
  border: 1px solid var(--border-color);
  border-radius: 0.75rem;
  padding: 1.5rem;
  margin-bottom: 1.5rem;
  box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.2);
}

.card h2 {
  font-size: 1.2rem;
  margin-bottom: 1rem;
  color: #fff;
}

/* Alerts */
.alert-banner {
  background-color: #7f1d1d;
  color: #fca5a5;
  border: 1px solid #ef4444;
  padding: 0.75rem 1rem;
  border-radius: 0.5rem;
  margin-bottom: 1.5rem;
  font-size: 0.9rem;
}

.hidden {
  display: none;
}

/* Form */
.form-group {
  margin-bottom: 1rem;
}

.form-group label {
  display: block;
  font-size: 0.85rem;
  color: var(--text-muted);
  margin-bottom: 0.4rem;
}

.form-group input {
  width: 100%;
  padding: 0.75rem;
  background-color: #0f172a;
  border: 1px solid var(--border-color);
  border-radius: 0.5rem;
  color: #fff;
  font-size: 0.95rem;
  outline: none;
  transition: border-color 0.2s;
}

.form-group input:focus {
  border-color: var(--primary-color);
}

.btn {
  display: inline-block;
  padding: 0.75rem 1.5rem;
  border-radius: 0.5rem;
  font-size: 0.95rem;
  font-weight: 600;
  cursor: pointer;
  border: none;
  transition: background-color 0.2s;
}

.btn-primary {
  background-color: var(--primary-color);
  color: #fff;
}

.btn-primary:hover {
  background-color: var(--primary-hover);
}

/* List & Tasks */
.list-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 1rem;
}

.task-stats {
  font-size: 0.85rem;
  color: var(--text-muted);
}

.task-stats .stat-item {
  margin-left: 1rem;
}

.todo-list {
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
}

.loading-state, .empty-state {
  text-align: center;
  padding: 2rem;
  color: var(--text-muted);
  font-size: 0.95rem;
}

.todo-item {
  display: flex;
  align-items: center;
  justify-content: space-between;
  background-color: #0f172a;
  border: 1px solid var(--border-color);
  padding: 0.85rem 1rem;
  border-radius: 0.5rem;
  transition: border-color 0.2s;
}

.todo-item:hover {
  border-color: #475569;
}

.todo-left {
  display: flex;
  align-items: center;
  gap: 0.85rem;
  flex: 1;
}

.todo-checkbox {
  width: 1.2rem;
  height: 1.2rem;
  cursor: pointer;
  accent-color: var(--primary-color);
}

.todo-content {
  display: flex;
  flex-direction: column;
  gap: 0.2rem;
}

.todo-title {
  font-size: 1rem;
  color: #fff;
}

.todo-desc {
  font-size: 0.85rem;
  color: var(--text-muted);
}

.todo-item.completed .todo-title {
  text-decoration: line-through;
  color: #64748b;
}

.btn-delete {
  background: none;
  border: none;
  color: var(--danger-color);
  cursor: pointer;
  padding: 0.35rem 0.65rem;
  border-radius: 0.25rem;
  font-size: 0.85rem;
  transition: all 0.2s;
}

.btn-delete:hover {
  background-color: rgba(239, 68, 68, 0.1);
  color: var(--danger-hover);
}
```

- [ ] **Step 3: Create `public/app.js`**

Create `public/app.js`:
```javascript
const API_BASE = '/api/todos';
const HEALTH_URL = '/health';

// DOM Elements
const envBadge = document.getElementById('env-badge');
const errorAlert = document.getElementById('error-alert');
const todoForm = document.getElementById('todo-form');
const titleInput = document.getElementById('todo-title');
const descInput = document.getElementById('todo-desc');
const todoList = document.getElementById('todo-list');
const totalCount = document.getElementById('total-count');
const completedCount = document.getElementById('completed-count');

let todos = [];

function showError(message) {
  errorAlert.textContent = message;
  errorAlert.classList.remove('hidden');
}

function clearError() {
  errorAlert.textContent = '';
  errorAlert.classList.add('hidden');
}

async function fetchDeploymentMetadata() {
  try {
    const res = await fetch(HEALTH_URL);
    if (!res.ok) throw new Error('Health check failed');
    const data = await res.json();

    const version = data.version || '1.0.0';
    const color = (data.color || 'blue').toLowerCase();

    envBadge.textContent = `v${version} [${color.toUpperCase()}]`;
    envBadge.className = 'badge';
    if (color === 'green') {
      envBadge.classList.add('badge-green');
    } else {
      envBadge.classList.add('badge-blue');
    }
  } catch (err) {
    envBadge.textContent = 'Offline';
    envBadge.className = 'badge badge-loading';
  }
}

function updateCounts() {
  totalCount.textContent = todos.length;
  completedCount.textContent = todos.filter((t) => t.completed).length;
}

function renderTodos() {
  if (todos.length === 0) {
    todoList.innerHTML = '<div class="empty-state">No tasks yet. Create one above!</div>';
    updateCounts();
    return;
  }

  todoList.innerHTML = todos
    .map(
      (todo) => `
      <div class="todo-item ${todo.completed ? 'completed' : ''}" data-id="${todo._id}">
        <div class="todo-left">
          <input
            type="checkbox"
            class="todo-checkbox"
            ${todo.completed ? 'checked' : ''}
            onchange="handleToggle('${todo._id}', this.checked)"
          />
          <div class="todo-content">
            <span class="todo-title">${escapeHtml(todo.title)}</span>
            ${todo.description ? `<span class="todo-desc">${escapeHtml(todo.description)}</span>` : ''}
          </div>
        </div>
        <button class="btn-delete" onclick="handleDelete('${todo._id}')">Delete</button>
      </div>
    `
    )
    .join('');

  updateCounts();
}

function escapeHtml(str) {
  const div = document.createElement('div');
  div.textContent = str;
  return div.innerHTML;
}

async function loadTodos() {
  try {
    const res = await fetch(API_BASE);
    const result = await res.json();
    if (result.success && Array.isArray(result.data)) {
      todos = result.data;
      renderTodos();
    } else {
      showError(result.message || 'Failed to load tasks');
    }
  } catch (err) {
    showError('Unable to connect to the Todo API');
  }
}

todoForm.addEventListener('submit', async (e) => {
  e.preventDefault();
  clearError();

  const title = titleInput.value.trim();
  const description = descInput.value.trim();

  if (!title) {
    showError('Task title cannot be empty');
    return;
  }

  try {
    const res = await fetch(API_BASE, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        title,
        ...(description ? { description } : {}),
      }),
    });

    const result = await res.json();
    if (res.ok && result.success) {
      todos.unshift(result.data);
      renderTodos();
      titleInput.value = '';
      descInput.value = '';
    } else {
      const errorMsg = result.errors
        ? result.errors.map((e) => e.message).join(', ')
        : result.message || 'Failed to create task';
      showError(errorMsg);
    }
  } catch (err) {
    showError('Network error while creating task');
  }
});

async function handleToggle(id, completed) {
  clearError();
  try {
    const res = await fetch(`${API_BASE}/${id}`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ completed }),
    });

    const result = await res.json();
    if (res.ok && result.success) {
      const idx = todos.findIndex((t) => t._id === id);
      if (idx !== -1) {
        todos[idx].completed = completed;
        renderTodos();
      }
    } else {
      showError(result.message || 'Failed to update task');
      loadTodos();
    }
  } catch (err) {
    showError('Network error while updating task');
  }
}

async function handleDelete(id) {
  clearError();
  try {
    const res = await fetch(`${API_BASE}/${id}`, { method: 'DELETE' });
    const result = await res.json();
    if (res.ok && result.success) {
      todos = todos.filter((t) => t._id !== id);
      renderTodos();
    } else {
      showError(result.message || 'Failed to delete task');
    }
  } catch (err) {
    showError('Network error while deleting task');
  }
}

// Global functions for inline HTML event handlers
window.handleToggle = handleToggle;
window.handleDelete = handleDelete;

// Initialize on page load
fetchDeploymentMetadata();
loadTodos();
```

- [ ] **Step 4: Commit Task 4**

```bash
git add public/index.html public/style.css public/app.js
git commit -m "feat: add static web frontend with live Blue/Green deployment badge and full CRUD"
```

---

### Task 5: Configure Nginx Static Hosting and Docker Compose Integration

**Files:**
- Modify: `nginx/nginx.conf`
- Modify: `docker-compose.yml`

**Interfaces:**
- Produces: Nginx reverse proxy serving `./public` on `/` and proxying `/api` & `/health` to `app:3000`.

- [ ] **Step 1: Update `nginx/nginx.conf`**

Modify `nginx/nginx.conf`:
```nginx
upstream app {
    server app:3000;
    keepalive 16;
}

server {
    listen 80;
    server_name _;

    client_max_body_size 1m;

    # Security Headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    # Serve static frontend
    location / {
        root   /usr/share/nginx/html;
        index  index.html;
        try_files $uri $uri/ /index.html;
    }

    # Proxy API endpoints
    location /api {
        proxy_pass         http://app;
        proxy_http_version 1.1;
        proxy_set_header   Connection "";
        proxy_set_header   Host $host;
        proxy_set_header   X-Real-IP $remote_addr;
        proxy_set_header   X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto $scheme;
        proxy_connect_timeout 60s;
        proxy_send_timeout    60s;
        proxy_read_timeout    60s;
    }

    # Proxy Health endpoint
    location /health {
        proxy_pass         http://app;
        proxy_http_version 1.1;
        proxy_set_header   Host $host;
    }
}
```

- [ ] **Step 2: Update `docker-compose.yml` to mount public volume into Nginx and set deployment envs**

Modify `docker-compose.yml`:
```yaml
services:
  # ── Node.js Application ──────────────────────────────────────────────────────
  app:
    image: pratik0207/todolist-app:latest
    build:
      context: .
      dockerfile: Dockerfile
      target: production
    container_name: todo_app
    restart: unless-stopped
    env_file: .env
    environment:
      - NODE_ENV=production
      - MONGO_URI=mongodb://mongo:27017/tododb
      - APP_VERSION=1.0.0
      - APP_COLOR=blue
    depends_on:
      mongo:
        condition: service_healthy
    networks:
      - todo_network

  # ── MongoDB ──────────────────────────────────────────────────────────────────
  mongo:
    image: mongo:7.0
    container_name: todo_mongo
    restart: unless-stopped
    volumes:
      - mongo_data:/data/db
    networks:
      - todo_network
    healthcheck:
      test: ["CMD", "mongosh", "--eval", "db.adminCommand('ping')"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 20s

  # ── Nginx Reverse Proxy & Static Host ────────────────────────────────────────
  nginx:
    image: nginx:1.27-alpine
    container_name: todo_nginx
    restart: unless-stopped
    ports:
      - "80:80"
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/conf.d/default.conf:ro
      - ./public:/usr/share/nginx/html:ro
    depends_on:
      - app
    networks:
      - todo_network

# ── Named Volumes ────────────────────────────────────────────────────────────
volumes:
  mongo_data:
    driver: local

# ── Networks ─────────────────────────────────────────────────────────────────
networks:
  todo_network:
    driver: bridge
```

- [ ] **Step 3: Build and run Docker containers**

Run:
```bash
docker compose up --build -d
```
Expected: All 3 containers (`todo_mongo`, `todo_app`, `todo_nginx`) start and report running/healthy.

- [ ] **Step 4: Verify static asset delivery and API proxying via curl**

Run:
```bash
curl -i http://localhost/
curl -i http://localhost/health
```
Expected:
- `http://localhost/` returns HTTP 200 with HTML content containing `Cloud Todo List` and `<span id="env-badge"`.
- `http://localhost/health` returns HTTP 200 with JSON `{ "status": "ok", "version": "1.0.0", "color": "blue" }`.

- [ ] **Step 5: Commit Task 5**

```bash
git add nginx/nginx.conf docker-compose.yml
git commit -m "feat: configure Nginx static web hosting and Docker Compose deployment metadata"
```
