const express = require('express');
const router = express.Router();
const {
  getAllTodos,
  getTodoById,
  createTodo,
  updateTodo,
  deleteTodo,
} = require('../controllers/todoController');

// GET  /api/todos       — list all todos
// POST /api/todos       — create a new todo
router.route('/').get(getAllTodos).post(createTodo);

// GET    /api/todos/:id — get a single todo
// PUT    /api/todos/:id — update a todo
// DELETE /api/todos/:id — delete a todo
router.route('/:id').get(getTodoById).put(updateTodo).delete(deleteTodo);

module.exports = router;

