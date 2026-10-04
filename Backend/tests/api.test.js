const request = require('supertest');
const jwt = require('jsonwebtoken');
const config = require('../src/config/env');

// Mock db query before loading app
jest.mock('../src/config/db', () => {
  const mockStudents = [
    {
      nim: '2200018051',
      name: 'AHMAD RIZKI',
      faculty: 'FTI',
      study_program: 'SISTEM INFORMASI',
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
      vehicles: [
        {
          id: 'v-1',
          student_nim: '2200018051',
          vehicle_number: 'AB 1234 SI',
          vehicle_type: 'PCX',
          vehicle_brand: 'Honda',
          is_primary: true,
          notes: 'Motor Utama',
        },
        {
          id: 'v-2',
          student_nim: '2200018051',
          vehicle_number: 'AB 9999 UAD',
          vehicle_type: 'Beat',
          vehicle_brand: 'Honda',
          is_primary: false,
          notes: 'Motor Cadangan',
        },
      ],
    },
  ];

  const mockScanHistory = [
    {
      id: 'h-1',
      student_nim: '2200018051',
      vehicle_id: 'v-1',
      vehicle_number: 'AB 1234 SI',
      vehicle_type: 'PCX',
      student_name: 'AHMAD RIZKI',
      faculty: 'FTI',
      study_program: 'SISTEM INFORMASI',
      scan_time: new Date().toISOString(),
      scan_method: 'barcode',
      location: 'Gate 1',
    },
  ];

  return {
    query: jest.fn(async (text, params) => {
      const sql = text.toLowerCase();

      // Count query
      if (sql.includes('count(*)')) {
        return { rows: [{ total: '1' }] };
      }

      // Lookup vehicle
      if (sql.includes('matched_vehicle_number')) {
        return {
          rows: [
            {
              matched_vehicle_id: 'v-1',
              matched_vehicle_number: 'AB 1234 SI',
              matched_vehicle_type: 'PCX',
              matched_vehicle_brand: 'Honda',
              matched_is_primary: true,
              nim: '2200018051',
              name: 'AHMAD RIZKI',
              faculty: 'FTI',
              study_program: 'SISTEM INFORMASI',
              created_at: new Date().toISOString(),
              updated_at: new Date().toISOString(),
              vehicles: mockStudents[0].vehicles,
            },
          ],
        };
      }

      // Students query
      if (sql.includes('from public.students')) {
        return { rows: mockStudents };
      }

      // Vehicles query
      if (sql.includes('from public.vehicles')) {
        return { rows: mockStudents[0].vehicles };
      }

      // Scan history query
      if (sql.includes('from public.scan_history')) {
        return { rows: mockScanHistory };
      }

      // Insert scan history
      if (sql.includes('insert into public.scan_history')) {
        return { rows: [mockScanHistory[0]] };
      }

      // Users query
      if (sql.includes('from public.users')) {
        return {
          rows: [
            {
              id: 'u-1',
              email: 'admin@uad.ac.id',
              name: 'Admin UAD',
              role: 'admin',
              created_at: new Date().toISOString(),
            },
          ],
        };
      }

      // Benchmark logs query
      if (sql.includes('from public.benchmark_logs')) {
        return {
          rows: [
            {
              id: 'b-1',
              run_id: 'QR-001',
              method: 'QR',
              scan_or_ocr_time_ms: 120,
              query_time_ms: 45,
              total_time_ms: 165,
              verification_status: 'valid',
              created_at: new Date().toISOString(),
            },
          ],
        };
      }

      // Insert benchmark log
      if (sql.includes('insert into public.benchmark_logs')) {
        return {
          rows: [
            {
              id: 'b-1',
              run_id: 'QR-001',
              method: 'QR',
              total_time_ms: 165,
              created_at: new Date().toISOString(),
            },
          ],
        };
      }

      return { rows: [] };
    }),
    getPool: jest.fn(() => ({})),
  };
});

const app = require('../src/app');

describe('=== STNK Check UAD Backend API Tests (Direct PostgreSQL) ===', () => {
  let authToken;

  beforeAll(() => {
    authToken = jwt.sign(
      { id: 'u-1', email: 'admin@uad.ac.id', name: 'Admin UAD', role: 'admin' },
      config.jwtSecret,
      { expiresIn: '1h' }
    );
  });

  test('1. GET /health - Status healthy 200', async () => {
    const res = await request(app).get('/health');
    expect(res.statusCode).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.data.status).toBe('healthy');
  });

  test('2. GET / - Info root server', async () => {
    const res = await request(app).get('/');
    expect(res.statusCode).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.data.service).toContain('STNK Check UAD');
  });

  test('3. Route 404 Not Found', async () => {
    const res = await request(app).get('/api/v1/halaman-tidak-ada');
    expect(res.statusCode).toBe(404);
    expect(res.body.success).toBe(false);
  });

  test('4. Validation Error saat register tanpa data lengkap', async () => {
    const res = await request(app)
      .post('/api/v1/auth/register')
      .send({ email: 'bukan-email' });
    expect(res.statusCode).toBe(400);
    expect(res.body.success).toBe(false);
    expect(res.body.errors).toBeDefined();
  });

  test('5. GET /api/v1/students - Daftar mahasiswa dengan multi-kendaraan', async () => {
    const res = await request(app).get('/api/v1/students');
    expect(res.statusCode).toBe(200);
    expect(res.body.success).toBe(true);
    expect(Array.isArray(res.body.data)).toBe(true);
    expect(res.body.data[0].nim).toBe('2200018051');
    // Backward compatibility
    expect(res.body.data[0].vehicle_number).toBe('AB 1234 SI');
    // Multi kendaraan
    expect(res.body.data[0].vehicles.length).toBe(2);
  });

  test('6. GET /api/v1/students/:nim - Detail mahasiswa berdasarkan NIM', async () => {
    const res = await request(app).get('/api/v1/students/2200018051');
    expect(res.statusCode).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.data.nim).toBe('2200018051');
    expect(res.body.data.vehicles.length).toBe(2);
  });

  test('7. GET /api/v1/students/vehicle/:vehicleNumber - Lookup kendaraan', async () => {
    const res = await request(app).get('/api/v1/students/vehicle/AB1234SI');
    expect(res.statusCode).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.data.matched_vehicle.vehicle_number).toBe('AB 1234 SI');
    expect(res.body.data.student.name).toBe('AHMAD RIZKI');
  });

  test('8. GET /api/v1/scan-history - Riwayat scan', async () => {
    const res = await request(app).get('/api/v1/scan-history');
    expect(res.statusCode).toBe(200);
    expect(res.body.success).toBe(true);
    expect(Array.isArray(res.body.data)).toBe(true);
  });

  test('9. POST /api/v1/scan-history - Simpan riwayat scan', async () => {
    const res = await request(app)
      .post('/api/v1/scan-history')
      .send({
        student_nim: '2200018051',
        student_name: 'AHMAD RIZKI',
        vehicle_number: 'AB 1234 SI',
        vehicle_type: 'PCX',
        scan_method: 'barcode',
      });
    expect(res.statusCode).toBe(201);
    expect(res.body.success).toBe(true);
  });

  test('10. GET /api/v1/auth/me - Cek token JWT pengguna terotentikasi', async () => {
    const res = await request(app)
      .get('/api/v1/auth/me')
      .set('Authorization', `Bearer ${authToken}`);
    expect(res.statusCode).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.data.email).toBe('admin@uad.ac.id');
  });

  test('11. POST /api/v1/benchmarks - Simpan log performa QR/OCR', async () => {
    const res = await request(app)
      .post('/api/v1/benchmarks')
      .send({
        run_id: 'QR-001',
        method: 'QR',
        scan_or_ocr_time_ms: 120,
        query_time_ms: 45,
        total_time_ms: 165,
        student_found: true,
        vehicle_found: true,
        verification_status: 'valid',
      });
    expect(res.statusCode).toBe(201);
    expect(res.body.success).toBe(true);
  });

  test('12. GET /api/v1/benchmarks - Ambil daftar log pengujian', async () => {
    const res = await request(app).get('/api/v1/benchmarks');
    expect(res.statusCode).toBe(200);
    expect(res.body.success).toBe(true);
    expect(Array.isArray(res.body.data)).toBe(true);
  });

  test('13. GET /api/v1/benchmarks/export-csv - Unduh file CSV Bab 4', async () => {
    const res = await request(app).get('/api/v1/benchmarks/export-csv');
    expect(res.statusCode).toBe(200);
    expect(res.headers['content-type']).toContain('text/csv');
    expect(res.text).toContain('run_id,timestamp,method');
  });
});
