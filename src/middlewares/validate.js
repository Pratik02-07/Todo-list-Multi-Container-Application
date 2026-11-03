const { z } = require('zod');

// Ensure backward compatibility with Zod 3 error customization options (required_error, invalid_type_error) in Zod 4
if (typeof z.setErrorMap === 'function') {
  z.setErrorMap((issue) => {
    if (issue.input === undefined && (issue.schema?.def?.required_error || issue.inst?.def?.required_error)) {
      return { message: issue.schema?.def?.required_error || issue.inst?.def?.required_error };
    }
    if (issue.code === 'invalid_type' && (issue.schema?.def?.invalid_type_error || issue.inst?.def?.invalid_type_error)) {
      return { message: issue.schema?.def?.invalid_type_error || issue.inst?.def?.invalid_type_error };
    }
  });
}

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
        const issues = result.error.issues || result.error.errors || [];
        issues.forEach((err) => {
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
