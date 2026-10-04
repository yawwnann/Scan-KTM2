const fs = require('fs');
const path = require('path');
const { getPool } = require('../config/db');
const logger = require('../utils/logger');

async function runMigration() {
  logger.info('🚀 Menjalankan migrasi skema database ke Supabase PostgreSQL...');

  try {
    const pool = getPool();
    const schemaFile = path.resolve(__dirname, 'schema.sql');
    const sql = fs.readFileSync(schemaFile, 'utf8');

    logger.info('Mengeksekusi SQL skema...');
    await pool.query(sql);

    // Pastikan constraint log audit scan_history dilepas jika sebelumnya ada
    await pool.query(`
      ALTER TABLE public.scan_history DROP CONSTRAINT IF EXISTS scan_history_student_nim_fkey;
      ALTER TABLE public.scan_history DROP CONSTRAINT IF EXISTS scan_history_vehicle_id_fkey;
    `);

    logger.info('✅ Skema tabel Supabase berhasil dibuat/diperbarui dengan sukses!');
    process.exit(0);
  } catch (error) {
    logger.error('❌ Gagal menjalankan migrasi:', error.message);
    if (error.message.includes('[YOUR-PASSWORD]')) {
      logger.error(
        'Petunjuk: Buka file Backend/.env lalu ganti [YOUR-PASSWORD] dengan password database Supabase Anda.'
      );
    }
    process.exit(1);
  }
}

runMigration();
