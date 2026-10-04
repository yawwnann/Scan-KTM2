const ApiResponse = require('../utils/apiResponse');
const logger = require('../utils/logger');
const config = require('../config/env');

// Handle 404 Route Not Found
const notFoundHandler = (req, res, next) => {
  return ApiResponse.notFound(
    res,
    `Route ${req.method} ${req.originalUrl} not found on this server`
  );
};

// Central Error Handler
const errorHandler = (err, req, res, next) => {
  logger.error(`Unhandled Error: ${err.message}`, {
    stack: err.stack,
    url: req.originalUrl,
    method: req.method,
  });

  const statusCode = err.statusCode || err.status || 500;
  const message = err.message || 'Internal Server Error';

  const errors = config.isDev ? { stack: err.stack } : null;

  return ApiResponse.error(res, message, statusCode, errors);
};

module.exports = {
  notFoundHandler,
  errorHandler,
};
