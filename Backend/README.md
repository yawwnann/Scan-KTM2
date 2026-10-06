# 🚀 STNK Check UAD - Backend API (Express.js & Direct Supabase PostgreSQL)

Backend RESTful API untuk aplikasi **STNK Check UAD** menggunakan **Express.js** dan koneksi langsung **PostgreSQL (Supabase)**. Mendukung sistem pemindaian KTM/Barcode, OCR, verifikasi plat kendaraan, riwayat pemindaian, serta relasi **1-to-N (satu mahasiswa dapat memiliki banyak kendaraan)**.

---

## 🌟 Fitur Utama

- **Direct PostgreSQL Connection (`pg`)**: Terhubung langsung ke database Supabase via `DATABASE_URL` (port 5432) dengan performa tinggi dan query SQL asli (`json_agg`, relasi, transaksi).
- **Multi-Kendaraan (1-to-N)**: Setiap mahasiswa dapat mendaftarkan lebih dari satu kendaraan (motor/mobil), lengkap dengan tanda kendaraan utama (*primary*).
- **Pencarian Cepat**:
  - Berdasarkan **NIM / Barcode KTM**.
  - Berdasarkan **Nomor Plat Kendaraan** (langsung mengenali pemiliknya).
  - Berdasarkan **Nama & Fakultas**.
- **Autentikasi Mandiri (JWT + Bcrypt)**: Registrasi dan login aman tanpa ketergantungan API eksternal.
- **Log Riwayat Pemindaian (Scan History)**: Rekam jejak verifikasi kendaraan di gerbang kampus.
- **Offline Sync Bridge**: Endpoint batch untuk sinkronisasi data dari SQLite offline Flutter.
- **Backward Compatible**: Menyediakan properti `vehicle_number`, `vehicle_type`, `vehicle_brand` di level root agar model Flutter lama tetap berjalan tanpa *break*.

---

## 📁 Struktur Direktori

```
Backend/
├── .env                      # File konfigurasi (isi password database Anda di sini)
├── .env.example              # Template variabel lingkungan
├── package.json              # Dependensi & script proyek
├── index.js                  # Entry point server
├── src/
│   ├── app.js                # Konfigurasi Express, middleware, CORS & error handling
│   ├── config/
│   │   ├── env.js            # Environment config loader
│   │   └── db.js             # Direct PostgreSQL Connection Pool (pg.Pool)
│   ├── controllers/
│   │   ├── authController.js
│   │   ├── studentController.js
│   │   ├── vehicleController.js
│   │   ├── scanHistoryController.js
│   │   └── statsController.js
│   ├── middlewares/
│   │   ├── authMiddleware.js # Verifikasi JWT
│   │   ├── roleMiddleware.js # Proteksi role (admin)
│   │   ├── validateMiddleware.js # Validasi input
│   │   └── errorMiddleware.js# Error & 404 handler
│   ├── routes/
│   │   ├── authRoutes.js
│   │   ├── studentRoutes.js
│   │   ├── vehicleRoutes.js
│   │   ├── scanHistoryRoutes.js
│   │   ├── statsRoutes.js
│   │   └── index.js
│   ├── services/
│   │   ├── authService.js
│   │   ├── studentService.js
│   │   ├── vehicleService.js
│   │   ├── scanHistoryService.js
│   │   └── statsService.js
│   ├── utils/
│   │   ├── apiResponse.js    # Format respon standar
│   │   └── logger.js
│   └── db/
│       ├── schema.sql        # Skema DDL PostgreSQL untuk Supabase
│       ├── migrate.js        # Script auto-migration skema ke Supabase
│       ├── seed.js           # Seeding data contoh dari firebase_data.json
│       └── clear.js          # Seeder pembersih (hapus seluruh data database)
└── tests/
    └── api.test.js           # Automated test suite (Jest + Supertest)
```

---

## ⚙️ Panduan Setup Supabase Direct

### 1. Konfigurasi `.env`
Buka file `Backend/.env` dan masukkan password database Supabase Anda:
```env
PORT=5000
NODE_ENV=development

# Ganti [YOUR-PASSWORD] dengan password database Supabase Anda yang sebenarnya
DATABASE_URL=postgresql://postgres:[YOUR-PASSWORD]@db.fzclnrrnhizwlcdfqrrf.supabase.co:5432/postgres

JWT_SECRET=stnk-check-uad-super-secret-key-2026
CORS_ORIGIN=*
```

### 2. Jalankan Migrasi Skema ke Supabase
Cukup jalankan satu perintah ini, tabel `users`, `students`, `vehicles`, dan `scan_history` beserta trigger dan index-nya akan otomatis dibuat di Supabase:
```bash
npm run db:migrate
```

### 3. Masukkan Data Awal (Seeding)
Jalankan script seed untuk memasukkan 14 data contoh mahasiswa UAD dari `firebase_data.json` serta akun admin default:
```bash
npm run seed
```
> **Akun Admin Default**:
> - Email: `admin@uad.ac.id`
> - Password: `admin123`

### 4. Menghapus / Membersihkan Semua Data (Clear Seeder)
Jika Anda ingin menghapus seluruh data pada database Supabase (`students`, `vehicles`, `scan_history`, `benchmark_logs`, dan `users`):
```bash
npm run seed:clear
```
> **Catatan Opsi**:
> - Jalankan `npm run seed:clear -- --keep-users` jika ingin menghapus seluruh data transaksi/mahasiswa/kendaraan tanpa menghapus akun pengguna (users).
> - Jalankan `npm run seed:reset` untuk mengosongkan seluruh database lalu langsung mengisinya kembali dengan data default.

### 5. Jalankan Server
```bash
# Mode pengembangan (auto-reload)
npm run dev

# Mode produksi
npm start
```
Server akan berjalan di: `http://localhost:5000`

---

## 🧪 Menjalankan Pengujian (Testing)

```bash
npm test
```
Seluruh 10 skenario unit & integration test akan dieksekusi menggunakan Jest dan Supertest.

---

## 📡 Ringkasan Endpoint API

| Method | Endpoint | Deskripsi |
|---|---|---|
| `GET` | `/health` | Status server |
| `POST` | `/api/v1/auth/login` | Login user & dapatkan token JWT |
| `POST` | `/api/v1/auth/register` | Registrasi user baru |
| `GET` | `/api/v1/auth/me` | Cek profil user login (`Authorization: Bearer <token>`) |
| `GET` | `/api/v1/students` | Ambil daftar mahasiswa (paginasi & filter) |
| `GET` | `/api/v1/students/:nim` | Detail mahasiswa + array seluruh kendaraannya |
| `GET` | `/api/v1/students/vehicle/:vehicleNumber` | Cari mahasiswa pemilik berdasarkan nomor plat |
| `POST` | `/api/v1/students` | Tambah mahasiswa baru |
| `POST` | `/api/v1/students/:nim/vehicles` | Tambah kendaraan ke-2, ke-3, dst ke mahasiswa |
| `PUT` | `/api/v1/vehicles/:vehicleId` | Update data kendaraan |
| `DELETE` | `/api/v1/vehicles/:vehicleId` | Hapus kendaraan |
| `POST` | `/api/v1/students/batch` | Bulk insert mahasiswa |
| `GET` | `/api/v1/scan-history` | Ambil riwayat pemindaian |
| `POST` | `/api/v1/scan-history` | Catat 1 riwayat scan baru |
| `POST` | `/api/v1/scan-history/batch` | Sinkronisasi massal log scan dari SQLite Flutter |
| `GET` | `/api/v1/stats` | Statistik total mahasiswa, kendaraan, scan hari ini |
