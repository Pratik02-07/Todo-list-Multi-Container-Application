
require('dotenv').config();
const express = require('express');
const mongoose = require('mongoose');
const connectDB = require('./config/db');
const todoRoutes = require('./routes/todoRoutes');
const errorHandler = require('./middlewares/errorHandler');
const AppError = require('./utils/AppError');

const app = express();
const PORT = process.env.PORT || 3000;

let startupComplete = false;

// Middleware
app.use(express.json());
app.use(express.urlencoded({ extended: false }));

// Liveness: confirms the Node.js process is responding
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

// Readiness: confirms MongoDB is connected
app.get('/ready', (req, res) => {
  const isDatabaseReady = mongoose.connection.readyState === 1;

  if (!isDatabaseReady) {
    return res.status(503).json({
      status: 'not-ready',
      database: 'disconnected',
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

// Start Server
const startServer = async () => {
  try {
    await connectDB();

    const server = app.listen(PORT, '0.0.0.0', () => {
      startupComplete = true;
      console.log(`Server running on port ${PORT}`);
    });

    return server;
  } catch (error) {
    console.error('Application startup failed:', error);
    process.exit(1);
  }
};

if (require.main === module) {
  startServer();
}

module.exports = app;
