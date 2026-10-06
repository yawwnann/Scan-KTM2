const { getPool } = require('../config/db');
const logger = require('../utils/logger');

const ALL_TABLES = [
  'public.benchmark_logs',
  'public.scan_history',
  'public.vehicles',
  'public.students',
  'public.users',
];

/**
 * Fungsi untuk menghapus seluruh data pada database PostgreSQL (Supabase)
 * @param {Object} options
 * @param {boolean} [options.keepUsers=false] - Jika true, data akun pengguna (public.users) tidak akan dihapus
 */
async function clearDatabase(options = {}) {
  const keepUsers =
    options.keepUsers ||
    process.argv.includes('--keep-users') ||
    process.argv.includes('--keep-admin');

  const targetTables = keepUsers
    ? ALL_TABLES.filter((t) => t !== 'public.users')
    : ALL_TABLES;

  logger.info('🚀 Memulai proses pembersihan seluruh data database (Clear Seeder)...');
  if (keepUsers) {
    logger.info('ℹ️  Opsi --keep-users terdeteksi: tabel public.users tidak akan dihapus.');
  }

  const pool = getPool();

  // 1. Ambil jumlah data sebelum dihapus
  const countBefore = {};
  for (const table of targetTables) {
    try {
      const res = await pool.query(`SELECT COUNT(*) AS total FROM ${table}`);
      countBefore[table] = parseInt(res.rows[0].total, 10);
    } catch (err) {
      countBefore[table] = 'N/A';
    }
  }

  // 2. Eksekusi penghapusan data
  try {
    const tableListSql = targetTables.join(', ');
    await pool.query(`TRUNCATE TABLE ${tableListSql} RESTART IDENTITY CASCADE;`);
    logger.info('✅ TRUNCATE CASCADE berhasil dieksekusi.');
  } catch (truncateErr) {
    logger.warn(`⚠️  TRUNCATE gagal (${truncateErr.message}), beralih ke fallback DELETE FROM...`);
    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      // Urutan penghapusan untuk relasi foreign key
      const deleteOrder = [
        'public.benchmark_logs',
        'public.scan_history',
        'public.vehicles',
        'public.students',
        ...(keepUsers ? [] : ['public.users']),
      ];
      for (const table of deleteOrder) {
        await client.query(`DELETE FROM ${table}`);
      }
      await client.query('COMMIT');
      logger.info('✅ Fallback DELETE FROM berhasil dieksekusi.');
    } catch (deleteErr) {
      await client.query('ROLLBACK');
      throw deleteErr;
    } finally {
      client.release();
    }
  }

  // 3. Verifikasi jumlah data setelah dihapus
  const countAfter = {};
  for (const table of targetTables) {
    try {
      const res = await pool.query(`SELECT COUNT(*) AS total FROM ${table}`);
      countAfter[table] = parseInt(res.rows[0].total, 10);
    } catch (err) {
      countAfter[table] = 'N/A';
    }
  }

  // 4. Tampilkan tabel ringkasan hasil pembersihan
  console.log('\n============================================================');
  console.log('   🧹 RINGKASAN PENGHAPUSAN DATA DATABASE (CLEAR SEEDER)');
  console.log('============================================================');
  for (const table of targetTables) {
    const before = countBefore[table];
    const after = countAfter[table];
    console.log(
      `  • ${table.padEnd(25)} : ${String(before).padStart(4)} data dihapus (Sisa: ${after})`
    );
  }
  console.log('============================================================');
  logger.info('✅ Seluruh data database berhasil dibersihkan dengan sukses!\n');

  return { countBefore, countAfter };
}

if (require.main === module) {
  clearDatabase()
    .then(() => {
      process.exit(0);
    })
    .catch((error) => {
      logger.error('❌ Gagal menghapus data database:', error.message);
      if (error.message && error.message.includes('[YOUR-PASSWORD]')) {
        logger.error(
          'Petunjuk: Masukkan password database Supabase di file Backend/.env'
        );
      }
      process.exit(1);
    });
}

module.exports = { clearDatabase };
