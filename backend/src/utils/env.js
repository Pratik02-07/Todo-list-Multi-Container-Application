const { z } = require('zod');

const envSchema = z.object({
  NODE_ENV: z.enum(['development', 'production', 'test']).default('development'),
  PORT: z.coerce.number().int().min(1).max(65535).default(3000),
  MONGO_URI: z.string().min(1, 'MONGO_URI must not be empty').default('mongodb://mongo:27017/tododb'),
});

const validateEnv = (config = process.env) => {
  const result = envSchema.safeParse(config);

  if (!result.success) {
    const errorDetails = result.error.issues
      .map((issue) => `${issue.path.join('.')}: ${issue.message}`)
      .join(', ');
    throw new Error(`Invalid environment variables: ${errorDetails}`);
  }

  return result.data;
};

module.exports = {
  envSchema,
  validateEnv,
};
