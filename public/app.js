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
