/**
 * Centralized global error handling middleware.
 */
const errorHandler = (err, req, res, _next) => {
  let statusCode = err.statusCode || err.status || 500;
  let message = err.message || 'Internal server error';
  let errors = err.errors;

  // Handle malformed JSON body parsed by express.json()
  if (err instanceof SyntaxError && (err.status === 400 || 'body' in err)) {
    statusCode = 400;
    message = 'Invalid JSON format in request body';
  }

  // Handle Mongoose CastError (invalid ObjectId)
  if (err.name === 'CastError') {
    statusCode = 400;
    message = `Invalid ID format: ${err.value}`;
  }

  // Handle Mongoose ValidationError
  if (err.name === 'ValidationError' && err.errors) {
    statusCode = 400;
    message = 'Validation failed';
    errors = Object.values(err.errors).map((e) => ({
      field: e.path,
      message: e.message,
    }));
  }

  // Hide 500 internal details for unhandled/non-operational errors or in production
  if (statusCode === 500 && (!err.isOperational || process.env.NODE_ENV === 'production')) {
    message = 'Internal server error';
  }

  if (statusCode === 500) {
    console.error('Unhandled Application Error:', err);
  }

  const response = {
    success: false,
    message,
  };

  if (Array.isArray(errors) && errors.length > 0) {
    response.errors = errors;
  }

  res.status(statusCode).json(response);
};

module.exports = errorHandler;

