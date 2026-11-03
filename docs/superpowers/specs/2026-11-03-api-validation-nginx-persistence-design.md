# Design Specification: API Validation, Nginx Reverse Proxy, and Persistence Testing

## 1. Overview
This specification details the enhancements to the Todo List Multi-Container application:
1. **API Validation & Error Handling**: Integrating `zod` schema validation for request payloads and route parameters, along with a centralized error handling pipeline providing structured HTTP responses.
2. **Production-Grade Nginx Reverse Proxy**: Configuring Nginx to act as the single public gateway on port 80, proxying `/api` and `/health` requests to the internal Node.js container, adding security headers and client body size limits.
3. **Persistence and Container Recovery Verification**: Providing an automated end-to-end verification script and manual procedure to validate data persistence in MongoDB's named volume across container lifecycle events and verify container recovery.

---

## 2. Architecture & Container Topology

```
                  ┌────────────────────────────────────────────────────────┐
                  │                 Docker Network: todo_network           │
  Client ──:80──▶ │  Nginx Reverse Proxy (:80)                             │
                  │  (container: todo_nginx)                               │
                  │                         │                              │
                  │                         ├──/api──▶ Node.js App (:3000) │
                  │                         └──/health (container: todo_app)
                  │                                         │              │
                  │                                         └──▶ MongoDB   │
                  │                                              (:27017)  │
                  │                                              volume:   │
                  │                                              mongo_data│
                  └────────────────────────────────────────────────────────┘
```

### Network Isolation
- `todo_app` does not publish port 3000 to the host machine.
- `todo_mongo` does not publish port 27017 to the host machine.
- `todo_nginx` publishes port `80:80` to the host machine, serving as the sole ingress point.
- All services communicate over the internal bridge network `todo_network`.

---

## 3. API Validation & Error Handling Design

### 3.1 Dependencies
- Add `zod` (`^3.23.8` or latest compatible) to `package.json` dependencies.

### 3.2 Zod Validation Schemas (`src/validators/todoValidator.js`)
Schemas enforce strict data validation and sanitization before request execution:
1. **`createTodoSchema`** (Request Body):
   - `title`: String, required, trimmed, min length 1, max length 200.
   - `description`: String, optional, trimmed, max length 1000.
   - `.strict()`: Disallows extraneous or unrecognized properties in the payload.
2. **`updateTodoSchema`** (Request Body):
   - `title`: String, optional, trimmed, min length 1, max length 200.
   - `description`: String, optional, trimmed, max length 1000.
   - `completed`: Boolean, optional.
   - `.strict()`: Disallows extraneous properties.
   - Refinement: Requires at least one of `title`, `description`, or `completed` to be present.
3. **`objectIdParamSchema`** (Route Parameters):
   - `id`: String matching `/^[0-9a-fA-F]{24}$/`, validating standard 24-character hexadecimal MongoDB ObjectIDs.

### 3.3 Validation Middleware (`src/middlewares/validate.js`)
A higher-order Express middleware function:
```javascript
validate({ body: schema, params: schema, query: schema })
```
- Validates the respective parts of `req`.
- On success: Replaces `req.body`, `req.params`, or `req.query` with the sanitized/parsed data and calls `next()`.
- On failure: Halts execution immediately and passes a structured `ValidationError` or returns a `400 Bad Request` response:
```json
{
  "success": false,
  "message": "Validation failed",
  "errors": [
    {
      "field": "title",
      "message": "Title cannot be empty"
    }
  ]
}
```

### 3.4 Centralized Error Handler (`src/middlewares/errorHandler.js` & `src/utils/AppError.js`)
Replaces ad-hoc try/catch responses with standardized error processing:
- **`AppError`**: Custom error class capturing HTTP status code and operational flag.
- **`errorHandler`** middleware:
  - `SyntaxError` with `status: 400` (e.g., malformed JSON): Returns 400 with `"Invalid JSON format"`.
  - `ZodError` or custom validation error: Returns 400 with list of formatted field issues.
  - Mongoose `CastError`: Returns 400 with `"Invalid ID format"`.
  - Mongoose `ValidationError`: Returns 400 with concatenated schema validation messages.
  - Route not found: Returns 404 with `"Route not found: METHOD /path"`.
  - Unhandled 500 errors: Logs stack trace to console, returns `{ "success": false, "message": "Internal server error" }`. Only exposes error details/stack in non-production environments.

### 3.5 Updated Route Handlers (`src/routes/todoRoutes.js`)
- `POST /api/todos`: Preceded by `validate({ body: createTodoSchema })`.
- `GET /api/todos/:id`: Preceded by `validate({ params: objectIdParamSchema })`.
- `PUT /api/todos/:id`: Preceded by `validate({ params: objectIdParamSchema, body: updateTodoSchema })`.
- `DELETE /api/todos/:id`: Preceded by `validate({ params: objectIdParamSchema })`.

---

## 4. Nginx Reverse Proxy Configuration

### 4.1 Configuration File (`nginx/nginx.conf`)
- **Upstream Block**:
  ```nginx
  upstream app {
      server app:3000;
      keepalive 16;
  }
  ```
- **Security & Buffer Limits**:
  - `client_max_body_size 1m;`
  - `add_header X-Frame-Options "SAMEORIGIN" always;`
  - `add_header X-Content-Type-Options "nosniff" always;`
  - `add_header X-XSS-Protection "1; mode=block" always;`
- **Reverse Proxy Routing**:
  - `location /api`:
    - `proxy_pass http://app;`
    - `proxy_http_version 1.1;`
    - `proxy_set_header Connection "";`
    - `proxy_set_header Host $host;`
    - `proxy_set_header X-Real-IP $remote_addr;`
    - `proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;`
    - `proxy_set_header X-Forwarded-Proto $scheme;`
    - Timeouts: `proxy_connect_timeout 60s; proxy_send_timeout 60s; proxy_read_timeout 60s;`
  - `location /health`: Proxies to `http://app/health`.
  - `location /`: Returns `404` with JSON `{"success":false,"message":"Not Found"}` and `Content-Type: application/json`.

### 4.2 Docker Compose Integration (`docker-compose.yml`)
- `nginx` container:
  - Image: `nginx:1.27-alpine`
  - Container name: `todo_nginx`
  - Port mapping: `80:80`
  - Volume mount: `./nginx/nginx.conf:/etc/nginx/conf.d/default.conf:ro`
  - Depends on: `app`
  - Network: `todo_network`

---

## 5. Persistence & Container Recovery Verification

### 5.1 Verification Test Script (`scripts/verify-persistence-recovery.js`)
An automated Node.js test script utilizing standard HTTP requests and `child_process.execSync` to test the environment end-to-end:
1. **Health & Endpoint Check**:
   - `GET http://localhost/health` -> Verify status 200, `{ "status": "ok" }`.
   - `GET http://localhost/api/todos` -> Verify status 200.
2. **API Validation Testing**:
   - `POST http://localhost/api/todos` with `{}` -> Assert 400 with title validation error.
   - `POST http://localhost/api/todos` with extraneous key `{ "title": "Test", "extra": "invalid" }` -> Assert 400.
   - `GET http://localhost/api/todos/invalid-id-123` -> Assert 400 with ID format validation error.
   - `PUT http://localhost/api/todos/<validId>` with empty body `{}` -> Assert 400 with empty update error.
3. **CRUD & Persistence Baseline**:
   - Create a test Todo item: `POST /api/todos` with a distinct title `PERSISTENCE_TEST_<timestamp>`.
   - Record created `_id`.
4. **Container Recovery Test**:
   - Execute `docker restart todo_app`.
   - Poll `http://localhost/health` until recovered (assert within 15 seconds).
   - Execute `docker restart todo_mongo`.
   - Poll `http://localhost/api/todos` until connection re-established.
5. **Data Persistence Verification**:
   - Execute `docker compose down` (tears down containers and network, keeps `mongo_data` volume).
   - Execute `docker compose up -d`.
   - Poll `http://localhost/health` and wait for MongoDB health check to report healthy.
   - Query `GET /api/todos`.
   - Assert that the record `PERSISTENCE_TEST_<timestamp>` persists and matches original ID.
6. **Cleanup**:
   - Delete the test Todo item via `DELETE /api/todos/<id>`.
   - Confirm deletion.

---

## 6. Implementation Files Checklist
- `package.json`: Add `zod` dependency.
- `src/validators/todoValidator.js`: Schemas for create, update, and objectId.
- `src/middlewares/validate.js`: Generic validation middleware.
- `src/middlewares/errorHandler.js`: Centralized error handler.
- `src/routes/todoRoutes.js`: Apply validation middleware to routes.
- `src/controllers/todoController.js`: Clean up redundant manual checks, delegate to error handler.
- `src/server.js`: Integrate centralized error handler.
- `nginx/nginx.conf`: Enhanced headers and limits.
- `scripts/verify-persistence-recovery.js`: Automated verification script.
- `README.md`: Document testing procedure and updated API documentation.
