/**
 * Structured application logger.
 * Outputs JSON format in production environments and readable text in development.
 */

const isProduction = process.env.NODE_ENV === 'production';

const formatLog = (level, message, meta = {}) => {
  const timestamp = new Date().toISOString();

  if (isProduction) {
    return JSON.stringify({
      timestamp,
      level,
      message,
      ...meta,
    });
  }

  const metaString = Object.keys(meta).length > 0 ? ` ${JSON.stringify(meta)}` : '';
  return `[${timestamp}] [${level.toUpperCase()}]: ${message}${metaString}`;
};

const logger = {
  info: (message, meta) => {
    console.log(formatLog('info', message, meta));
  },
  warn: (message, meta) => {
    console.warn(formatLog('warn', message, meta));
  },
  error: (message, meta) => {
    console.error(formatLog('error', message, meta));
  },
  debug: (message, meta) => {
    if (process.env.DEBUG || !isProduction) {
      console.debug(formatLog('debug', message, meta));
    }
  },
};

module.exports = logger;
