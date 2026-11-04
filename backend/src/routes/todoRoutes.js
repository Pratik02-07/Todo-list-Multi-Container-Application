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
