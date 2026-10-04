const dotenv = require('dotenv');
const path = require('path');

// Load environment variables from .env
dotenv.config({ path: path.resolve(__dirname, '../../.env') });

const config = {
  port: parseInt(process.env.PORT, 10) || 5000,
  nodeEnv: process.env.NODE_ENV || 'development',
  isDev: (process.env.NODE_ENV || 'development') === 'development',
  corsOrigin: process.env.CORS_ORIGIN || '*',

  // Direct PostgreSQL Connection String ke Supabase
  databaseUrl:
    process.env.DATABASE_URL ||
    'postgresql://postgres:[YOUR-PASSWORD]@db.fzclnrrnhizwlcdfqrrf.supabase.co:5432/postgres',

  // JWT Configuration
  jwtSecret: process.env.JWT_SECRET || 'stnk-check-uad-default-secret-key-2026',
  jwtExpiresIn: '7d',

  // Supabase REST client configuration (opsional jika dibutuhkan)
  supabase: {
    url: process.env.SUPABASE_URL || 'https://fzclnrrnhizwlcdfqrrf.supabase.co',
    anonKey: process.env.SUPABASE_ANON_KEY || '',
    serviceRoleKey: process.env.SUPABASE_SERVICE_ROLE_KEY || '',
  },
};

module.exports = config;
