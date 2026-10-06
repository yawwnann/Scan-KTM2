const fs = require('fs');
const path = require('path');
const bcrypt = require('bcryptjs');
const { getPool } = require('../config/db');
const logger = require('../utils/logger');
const { clearDatabase } = require('./clear');

async function runSeed() {
  if (process.argv.includes('--clear') || process.argv.includes('--clean')) {
    await clearDatabase();
    process.exit(0);
  }

  if (process.argv.includes('--reset') || process.argv.includes('--fresh')) {
    await clearDatabase();
  }

  logger.info('🚀 Memulai proses seeding data ke Supabase PostgreSQL...');

  try {
    const pool = getPool();

    // 1. Buat Default User Admin (jika belum ada)
    const adminEmail = 'admin@uad.ac.id';
    const adminPassword = 'admin123';
    const hashedPassword = await bcrypt.hash(adminPassword, 10);

    await pool.query(
      `INSERT INTO public.users (email, password_hash, name, role)
       VALUES ($1, $2, $3, $4)
       ON CONFLICT (email) DO UPDATE 
       SET name = EXCLUDED.name, role = EXCLUDED.role`,
      [adminEmail, hashedPassword, 'Administrator UAD', 'admin']
    );
    logger.info(`✅ Akun Admin Default siap: ${adminEmail} (password: ${adminPassword})`);

    // 2. Baca data dari firebase_data.json di Frontend
    const jsonPath = path.resolve(__dirname, '../../../Frontend/firebase_data.json');
    let rawStudents = {};

    if (fs.existsSync(jsonPath)) {
      logger.info(`Membaca data dari: ${jsonPath}`);
      const fileContent = fs.readFileSync(jsonPath, 'utf8');
      const parsed = JSON.parse(fileContent);
      rawStudents = parsed.students || {};
    }

    const nims = Object.keys(rawStudents);
    logger.info(`Ditemukan ${nims.length} data mahasiswa untuk dimasukkan...`);

    for (const nim of nims) {
      const s = rawStudents[nim];
      const studentNim = s.nim || nim;
      const studentName = s.name || 'Mahasiswa UAD';
      const faculty = s.faculty || 'FTI';
      const studyProgram = s.studyProgram || s.study_program || 'Informatika';

      // Insert/Upsert Student
      await pool.query(
        `INSERT INTO public.students (nim, name, faculty, study_program)
         VALUES ($1, $2, $3, $4)
         ON CONFLICT (nim) DO UPDATE 
         SET name = EXCLUDED.name, faculty = EXCLUDED.faculty, study_program = EXCLUDED.study_program`,
        [studentNim, studentName, faculty, studyProgram]
      );

      // Insert Vehicle jika ada
      if (s.vehicleNumber) {
        const cleanPlate = s.vehicleNumber.trim().toUpperCase();
        await pool.query(
          `INSERT INTO public.vehicles (student_nim, vehicle_number, vehicle_type, vehicle_brand, is_primary)
           VALUES ($1, $2, $3, $4, $5)
           ON CONFLICT (vehicle_number) DO UPDATE
           SET vehicle_type = EXCLUDED.vehicle_type, vehicle_brand = EXCLUDED.vehicle_brand, student_nim = EXCLUDED.student_nim`,
          [
            studentNim,
            cleanPlate,
            s.vehicleType || 'Motor',
            s.vehicleBrand || 'Honda',
            true,
          ]
        );
      }
    }

    // Contoh Multi-Kendaraan: Tambah kendaraan kedua untuk mahasiswa pertama
    if (nims.length > 0) {
      const firstNim = rawStudents[nims[0]].nim || nims[0];
      await pool.query(
        `INSERT INTO public.vehicles (student_nim, vehicle_number, vehicle_type, vehicle_brand, is_primary, notes)
         VALUES ($1, $2, $3, $4, $5, $6)
         ON CONFLICT (vehicle_number) DO NOTHING`,
        [firstNim, 'AB 9999 UAD', 'Beat', 'Honda', false, 'Kendaraan Kedua (Contoh Multi-Kendaraan)']
      );
    }

    logger.info('✅ Seeding data selesai dengan sukses!');
    process.exit(0);
  } catch (error) {
    logger.error('❌ Gagal menjalankan seed:', error.message);
    if (error.message.includes('[YOUR-PASSWORD]')) {
      logger.error('Petunjuk: Masukkan password database Supabase di file Backend/.env');
    }
    process.exit(1);
  }
}

runSeed();
