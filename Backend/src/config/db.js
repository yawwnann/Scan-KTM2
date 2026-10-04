const { Pool } = require('pg');
const config = require('./env');
const logger = require('../utils/logger');

let pool = null;

const isConfigured =
  config.databaseUrl &&
  !config.databaseUrl.includes('[YOUR-PASSWORD]') &&
  !config.databaseUrl.includes('your-project-id');

if (!isConfigured) {
  logger.warn(
    'PostgreSQL DATABASE_URL belum diisi dengan password yang benar pada file .env!'
  );
} else {
  try {
    pool = new Pool({
      connectionString: config.databaseUrl,
      ssl:
        config.databaseUrl.includes('supabase') ||
        config.databaseUrl.includes('sslmode=require')
          ? { rejectUnauthorized: false }
          : false,
      max: 20,
      idleTimeoutMillis: 30000,
      connectionTimeoutMillis: 10000,
    });

    pool.on('error', (err) => {
      logger.error('Unexpected error on idle PostgreSQL client:', err.message);
    });

    logger.info('PostgreSQL Pool initialized for direct Supabase connection');
  } catch (error) {
    logger.error('Failed to initialize PostgreSQL pool:', error.message);
  }
}

const getPool = () => {
  if (!pool) {
    throw new Error(
      'Database belum terkonfigurasi. Silakan ganti [YOUR-PASSWORD] di file Backend/.env dengan password Supabase Anda.'
    );
  }
  return pool;
};

const query = async (text, params) => {
  const currentPool = getPool();
  const start = Date.now();
  const res = await currentPool.query(text, params);
  const duration = Date.now() - start;
  logger.debug('Executed query', { text, duration, rows: res.rowCount });
  return res;
};

module.exports = {
  pool,
  getPool,
  query,
};
