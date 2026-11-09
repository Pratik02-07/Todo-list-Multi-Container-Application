const mongoose = require('mongoose');
const logger = require('../utils/logger');

let isConnected = false;

// Attach event listeners once
mongoose.connection.on('connected', () => {
  isConnected = true;
  logger.info('MongoDB connection established');
});

mongoose.connection.on('error', (err) => {
  isConnected = false;
  logger.error('MongoDB connection error', { error: err.message });
});

mongoose.connection.on('disconnected', () => {
  isConnected = false;
  logger.warn('MongoDB connection lost / disconnected');
});

mongoose.connection.on('reconnected', () => {
  isConnected = true;
  logger.info('MongoDB reconnected successfully');
});

/**
 * Connects to MongoDB with connection pooling and timeouts.
 * @param {string} [uri] - Optional MongoDB URI (defaults to process.env.MONGO_URI)
 */
const connectDB = async (uri = process.env.MONGO_URI) => {
  if (!uri) {
    throw new Error('MONGO_URI is required to establish database connection');
  }

  try {
    const conn = await mongoose.connect(uri, {
      serverSelectionTimeoutMS: 5000,
      connectTimeoutMS: 10000,
    });

    isConnected = true;
    logger.info('MongoDB initial connection successful', { host: conn.connection.host });
    return conn;
  } catch (error) {
    isConnected = false;
    logger.error('Failed to connect to MongoDB on startup', { error: error.message });
    throw error;
  }
};

/**
 * Gracefully closes the MongoDB connection.
 */
const closeDB = async () => {
  if (mongoose.connection.readyState !== 0) {
    await mongoose.connection.close(false);
    isConnected = false;
    logger.info('MongoDB connection closed cleanly');
  }
};

const getDBStatus = () => ({
  isConnected,
  readyState: mongoose.connection.readyState,
});

module.exports = {
  connectDB,
  closeDB,
  getDBStatus,
};
