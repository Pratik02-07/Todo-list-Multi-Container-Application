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
