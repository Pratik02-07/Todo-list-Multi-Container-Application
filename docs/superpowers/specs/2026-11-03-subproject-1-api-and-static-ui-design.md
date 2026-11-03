# Design Specification: Sub-Project 1 — Core API & Static Web UI with Deployment Metadata

## 1. Overview
Sub-Project 1 delivers the foundational application and user interface for the multi-container Todo system in preparation for Blue-Green zero-downtime deployment:
1. **Interactive Static Web UI**: Modern, responsive HTML5/CSS3/vanilla ES6 frontend served by Nginx, featuring a live deployment environment badge (`#env-badge`) displaying the active version and deployment color (e.g. **v1.0.0 [Blue]** vs **v2.0.0 [Green]**).
2. **Nginx Reverse Proxy & Static Host**: Configured on port 80 to directly deliver static web assets from `/usr/share/nginx/html` and proxy `/api/*` and `/health` requests to the internal Node.js container.
3. **API Validation & Centralized Error Handling**: Strict request payload and parameter validation powered by `zod`, coupled with a centralized error handling middleware returning uniform JSON responses.
4. **Health & Deployment Metadata**: Dynamic `/health` endpoint exposing `status`, `version`, `color`, and `uptime` based on container environment variables (`APP_VERSION`, `APP_COLOR`).

---

## 2. Architecture & Container Layout

```
                  ┌────────────────────────────────────────────────────────┐
                  │                 Docker Network: todo_network           │
  Client ──:80──▶ │  Nginx (:80)                                           │
                  │  (container: todo_nginx)                               │
                  │                         │                              │
                  │                         ├── GET / (static UI)          │
                  │                         │   mounted from ./public      │
                  │                         │                              │
                  │                         ├──/api──▶ Node.js App (:3000) │
                  │                         └──/health (container: todo_app)
                  │                                    │  [APP_VERSION]    │
                  │                                    │  [APP_COLOR]      │
                  │                                    └──▶ MongoDB        │
                  │                                         (:27017)       │
                  │                                         volume:        │
                  │                                         mongo_data     │
                  └────────────────────────────────────────────────────────┘
```

### Port Mapping & Security
- Only `todo_nginx` publishes port 80 to the host.
- `todo_app` runs internally on port 3000 and is not directly accessible from the host.
- `todo_mongo` runs internally on port 27017 with persistent volume `mongo_data`.

---

## 3. Static Web Frontend Specification (`public/`)

### 3.1 `public/index.html`
- **Document Structure**:
  - Semantic HTML5 with viewport meta tag for mobile responsiveness.
  - Header area: Application title and an interactive deployment indicator:
    ```html
    <div class="deployment-indicator">
      <span class="badge-label">Active Deployment:</span>
      <span id="env-badge" class="badge badge-loading">Connecting...</span>
    </div>
    ```
  - Error banner container (`#error-alert`) hidden by default, accessible via `role="alert"`.
  - Task Creation Form:
    - Input: `#todo-title` (type text, required, placeholder "What needs to be done?").
    - Input: `#todo-desc` (type text, optional, placeholder "Description (optional)").
    - Submit Button: `#btn-add-todo` ("Add Task").
  - Task List Section:
    - Task stats: Total count (`#total-count`) and Completed count (`#completed-count`).
    - List element: `#todo-list` rendering dynamic task cards.

### 3.2 `public/style.css`
- Modern design system with CSS custom properties (variables):
  - Primary font: Inter, system-ui, -apple-system, sans-serif.
  - Neutral dark background & clean card aesthetics.
  - Color themes for Blue and Green badges:
    - Blue theme: Background `#dbeafe`, text `#1e40af`, border `#93c5fd`.
    - Green theme: Background `#dcfce7`, text `#166534`, border `#86efac`.
  - Task item layout: Title with strike-through on completion, muted description, timestamp, completion checkbox, and delete button with hover states.

### 3.3 `public/app.js`
- **Module Responsibilities**:
  - `init()`:
    1. Fetches `/health` to obtain `{ status, version, color }`.
    2. Updates `#env-badge` text to `v${version} [${color.toUpperCase()}]` and toggles `.badge-blue` or `.badge-green`.
    3. Fetches `/api/todos` and populates the task list.
  - `addTodo(e)`:
    - Collects title and description.
    - Sends `POST /api/todos`.
    - On 201: Appends new task card, clears form inputs, and updates counters.
    - On 400: Displays structured error message(s) in `#error-alert`.
  - `toggleTodo(id, completed)`:
    - Sends `PUT /api/todos/:id` with `{ completed }`.
    - Updates task visual state and counters.
  - `deleteTodo(id)`:
    - Sends `DELETE /api/todos/:id`.
    - Removes task card with smooth transition.

---

## 4. Backend API & Error Handling Specification

### 4.1 Health Check & Metadata (`src/server.js`)
- Endpoint: `GET /health`
- Response:
  ```json
  {
    "status": "ok",
    "version": "1.0.0",
    "color": "blue",
    "uptime": 12.34,
    "timestamp": "2026-11-03T11:00:00.000Z"
  }
  ```
  Values dynamically read `process.env.APP_VERSION || '1.0.0'` and `process.env.APP_COLOR || 'blue'`.

### 4.2 Validation Schemas (`src/validators/todoValidator.js`)
- **`createTodoSchema`**:
  - `title`: String, trimmed, min 1, max 200, required.
  - `description`: String, trimmed, max 1000, optional.
  - `.strict()`: Rejects extra keys.
- **`updateTodoSchema`**:
  - `title`: String, trimmed, min 1, max 200, optional.
  - `description`: String, trimmed, max 1000, optional.
  - `completed`: Boolean, optional.
  - `.strict()`: Rejects extra keys.
  - Requires at least one field present.
- **`objectIdParamSchema`**:
  - `id`: String matching `/^[0-9a-fA-F]{24}$/`.

### 4.3 Validation Middleware (`src/middlewares/validate.js`)
- Universal middleware: `validate({ body, params, query })`.
- Replaces request properties with trimmed/parsed values.
- On failure: Returns HTTP `400 Bad Request`:
  ```json
  {
    "success": false,
    "message": "Validation failed",
    "errors": [
      { "location": "body", "field": "title", "message": "Title cannot be empty" }
    ]
  }
  ```

### 4.4 Centralized Error Handler (`src/middlewares/errorHandler.js` & `src/utils/AppError.js`)
- Handles:
  - `AppError(message, statusCode)`
  - Express JSON `SyntaxError` (400 Bad Request)
  - Mongoose `CastError` (400 Bad Request)
  - Mongoose `ValidationError` (400 Bad Request)
  - 404 Route Not Found
  - 500 Internal Server Errors (stack traces suppressed in production)

---

## 5. Nginx Configuration (`nginx/nginx.conf`)

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

---

## 6. Verification and Testing
1. **Automated Unit Tests**:
   - `tests/validators/todoValidator.test.js`: Validates all Zod schemas.
   - `tests/middlewares/validate.test.js`: Validates middleware parsing and error response structure.
   - `tests/middlewares/errorHandler.test.js`: Validates error conversions and status codes.
2. **Automated Integration Tests**:
   - `tests/integration/todoRoutes.test.js`: Tests all Express routes with validation and error handlers.
3. **End-to-End Container Verification**:
   - Docker Compose starts `todo_mongo`, `todo_app`, and `todo_nginx`.
   - Access `http://localhost/`: Serves static web UI with active badge.
   - Access `http://localhost/health`: Returns `{ status: "ok", version: "1.0.0", color: "blue" }`.
   - Perform Todo CRUD via the web page and verify database persistence.
