const isDev = process.env.NODE_ENV !== 'production';

const formatTimestamp = () => new Date().toISOString();

const logger = {
  info: (message, ...args) => {
    console.log(`[INFO]  [${formatTimestamp()}] ${message}`, ...args);
  },
  warn: (message, ...args) => {
    console.warn(`[WARN]  [${formatTimestamp()}] ${message}`, ...args);
  },
  error: (message, ...args) => {
    console.error(`[ERROR] [${formatTimestamp()}] ${message}`, ...args);
  },
  debug: (message, ...args) => {
    if (isDev) {
      console.debug(`[DEBUG] [${formatTimestamp()}] ${message}`, ...args);
    }
  },
};

module.exports = logger;
