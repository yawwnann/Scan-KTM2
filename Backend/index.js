const app = require('./src/app');
const config = require('./src/config/env');
const logger = require('./src/utils/logger');

const server = app.listen(config.port, () => {
  logger.info(`==================================================`);
  logger.info(`  STNK Check UAD Backend Server Started`);
  logger.info(`  Environment : ${config.nodeEnv}`);
  logger.info(`  Port        : ${config.port}`);
  logger.info(`  URL         : http://localhost:${config.port}`);
  logger.info(`  Healthcheck : http://localhost:${config.port}/health`);
  logger.info(`  API Base    : http://localhost:${config.port}/api/v1`);
  logger.info(`==================================================`);
});

// Graceful Shutdown
const handleShutdown = (signal) => {
  logger.info(`Received ${signal}. Shutting down gracefully...`);
  server.close(() => {
    logger.info('HTTP server closed.');
    process.exit(0);
  });

  setTimeout(() => {
    logger.error('Forced shutdown due to timeout.');
    process.exit(1);
  }, 10000);
};

process.on('SIGTERM', () => handleShutdown('SIGTERM'));
process.on('SIGINT', () => handleShutdown('SIGINT'));

module.exports = server;
