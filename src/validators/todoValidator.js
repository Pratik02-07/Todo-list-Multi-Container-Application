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
