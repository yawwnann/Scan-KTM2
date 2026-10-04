const { createClient } = require('@supabase/supabase-js');
const config = require('./env');
const logger = require('../utils/logger');

const { url, serviceRoleKey, anonKey } = config.supabase;

const supabaseKey = serviceRoleKey || anonKey;

let supabase = null;

if (!url || !supabaseKey || url.includes('your-project-id')) {
  logger.warn(
    'Supabase URL or Key is not configured yet! Please update your .env file with valid Supabase credentials.'
  );
} else {
  try {
    supabase = createClient(url, supabaseKey, {
      auth: {
        autoRefreshToken: false,
        persistSession: false,
      },
    });
    logger.info('Supabase client initialized successfully');
  } catch (error) {
    logger.error('Failed to initialize Supabase client:', error.message);
  }
}

// Helper getter that throws friendly error if client is not configured
const getSupabase = () => {
  if (!supabase) {
    throw new Error(
      'Supabase client is not configured. Please set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY or SUPABASE_ANON_KEY in .env'
    );
  }
  return supabase;
};

module.exports = {
  supabase,
  getSupabase,
};
