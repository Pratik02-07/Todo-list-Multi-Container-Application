require('dotenv').config();
const express = require('express');
const mongoose = require('mongoose');
const { connectDB, closeDB } = require('./config/db');
const todoRoutes = require('./routes/todoRoutes');
const errorHandler = require('./middlewares/errorHandler');
const AppError = require('./utils/AppError');
const logger = require('./utils/logger');
const { validateEnv } = require('./utils/env');

// Validate environment variables at boot
const env = validateEnv();

const app = express();
const PORT = env.PORT;

let startupComplete = false;
let isShuttingDown = false;

// Middleware
app.use(express.json());
app.use(express.urlencoded({ extended: false }));

// Reject new requests during graceful shutdown
app.use((req, res, next) => {
  if (isShuttingDown) {
    res.set('Connection', 'close');
    return res.status(503).json({
      status: 'terminating',
      message: 'Server is undergoing graceful shutdown',
    });
  }
  next();
});

// Liveness: confirms the Node.js process is responsive
app.get('/health', (req, res) => {
  res.status(200).json({
    status: 'alive',
    uptime: process.uptime(),
    timestamp: new Date().toISOString(),
  });
});

// Startup: confirms database initialization has completed
app.get('/health/startup', (req, res) => {
  if (!startupComplete) {
    return res.status(503).json({ status: 'starting' });
  }

  res.status(200).json({ status: 'started' });
});

// Readiness: confirms MongoDB is connected and ready
app.get('/ready', (req, res) => {
  const isDatabaseReady = mongoose.connection.readyState === 1;

  if (!isDatabaseReady || isShuttingDown) {
    return res.status(503).json({
      status: 'not-ready',
      database: isDatabaseReady ? 'shutting-down' : 'disconnected',
    });
  }

  res.status(200).json({
    status: 'ready',
    database: 'connected',
  });
});

// API Routes
app.use('/api/todos', todoRoutes);

// 404 Handler
app.use((req, res, next) => {
  next(new AppError(`Route not found: ${req.method} ${req.originalUrl}`, 404));
});

// Centralized Error Handler
app.use(errorHandler);

let activeServer = null;

// Graceful shutdown handler
const stopServer = async (server = activeServer) => {
  if (isShuttingDown) return;
  isShuttingDown = true;
  logger.info('Initiating graceful application shutdown...');

  return new Promise((resolve) => {
    const forceExitTimeout = setTimeout(() => {
      logger.error('Graceful shutdown timed out (10s limit). Forcing exit.');
      resolve();
    }, 10000);

    if (server) {
      server.close(async (err) => {
        if (err) {
          logger.error('Error closing HTTP server', { error: err.message });
        } else {
          logger.info('HTTP server closed cleanly, no new connections accepted.');
        }

        try {
          await closeDB();
        } catch (dbErr) {
          logger.error('Error disconnecting database', { error: dbErr.message });
        }

        clearTimeout(forceExitTimeout);
        logger.info('Graceful shutdown completed successfully.');
        resolve();
      });
    } else {
      closeDB().then(() => {
        clearTimeout(forceExitTimeout);
        resolve();
      });
    }
  });
};

// Start Server
const startServer = async (port = PORT, mongoUri = env.MONGO_URI) => {
  try {
    await connectDB(mongoUri);

    const server = app.listen(port, '0.0.0.0', () => {
      startupComplete = true;
      logger.info(`Server running on port ${port}`, {
        port,
        environment: env.NODE_ENV,
      });
    });

    activeServer = server;

    // Handle termination signals
    const handleSignal = async (signal) => {
      logger.info(`Received ${signal}. Shutting down application gracefully.`);
      await stopServer(server);
      process.exit(0);
    };

    process.on('SIGTERM', () => handleSignal('SIGTERM'));
    process.on('SIGINT', () => handleSignal('SIGINT'));

    return server;
  } catch (error) {
    logger.error('Application startup failed', { error: error.message });
    process.exit(1);
  }
};

if (require.main === module) {
  startServer();
}

module.exports = {
  app,
  startServer,
  stopServer,
};
