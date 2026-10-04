-- ============================================================================
-- DATABASE SCHEMA: STNK Check UAD (Direct PostgreSQL - Supabase)
-- ============================================================================

-- 1. Ekstensi UUID
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 2. TABEL PENGGUNA (Petugas / Admin / Operator)
CREATE TABLE IF NOT EXISTS public.users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email VARCHAR(255) UNIQUE NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  name VARCHAR(255) NOT NULL,
  role VARCHAR(50) NOT NULL DEFAULT 'user' CHECK (role IN ('admin', 'user', 'operator')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_users_email ON public.users(email);
CREATE INDEX IF NOT EXISTS idx_users_role ON public.users(role);

-- 3. TABEL MAHASISWA (Master Data Mahasiswa)
CREATE TABLE IF NOT EXISTS public.students (
  nim VARCHAR(50) PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  faculty VARCHAR(255) NOT NULL,
  study_program VARCHAR(255) NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_students_name ON public.students (LOWER(name));
CREATE INDEX IF NOT EXISTS idx_students_faculty ON public.students (faculty);
CREATE INDEX IF NOT EXISTS idx_students_study_program ON public.students (study_program);

-- 4. TABEL KENDARAAN (Relasi 1 Mahasiswa -> Banyak Kendaraan)
CREATE TABLE IF NOT EXISTS public.vehicles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  student_nim VARCHAR(50) NOT NULL REFERENCES public.students(nim) ON DELETE CASCADE,
  vehicle_number VARCHAR(50) NOT NULL,
  vehicle_type VARCHAR(100) NOT NULL, -- Contoh: 'Motor', 'Mobil', 'PCX', 'Vario'
  vehicle_brand VARCHAR(100) DEFAULT '', -- Contoh: 'Honda', 'Yamaha', 'Toyota'
  is_primary BOOLEAN DEFAULT false,
  notes TEXT DEFAULT '',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  CONSTRAINT uq_vehicle_number UNIQUE (vehicle_number)
);

CREATE INDEX IF NOT EXISTS idx_vehicles_student_nim ON public.vehicles (student_nim);
CREATE INDEX IF NOT EXISTS idx_vehicles_vehicle_number ON public.vehicles (UPPER(vehicle_number));
CREATE INDEX IF NOT EXISTS idx_vehicles_is_primary ON public.vehicles (is_primary);

-- 5. TABEL RIWAYAT SCAN (Scan History - Audit Event Log)
CREATE TABLE IF NOT EXISTS public.scan_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  student_nim VARCHAR(50),
  vehicle_id UUID,
  vehicle_number VARCHAR(50) NOT NULL,
  vehicle_type VARCHAR(100) DEFAULT '',
  student_name VARCHAR(255) NOT NULL,
  faculty VARCHAR(255) NOT NULL,
  study_program VARCHAR(255) NOT NULL,
  scan_time TIMESTAMPTZ DEFAULT NOW(),
  scan_method VARCHAR(50) DEFAULT 'barcode', -- 'barcode', 'ocr', 'manual'
  location VARCHAR(255) DEFAULT 'Campus Gate',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_scan_history_student_nim ON public.scan_history (student_nim);
CREATE INDEX IF NOT EXISTS idx_scan_history_vehicle_number ON public.scan_history (vehicle_number);
CREATE INDEX IF NOT EXISTS idx_scan_history_scan_time ON public.scan_history (scan_time DESC);

-- 6. TABEL LOG PENGUJIAN PERFORMA (Benchmark Bab 4 Skripsi)
CREATE TABLE IF NOT EXISTS public.benchmark_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  run_id VARCHAR(50) NOT NULL,
  method VARCHAR(20) NOT NULL, -- 'QR' atau 'OCR'
  image_load_time_ms INTEGER DEFAULT 0,
  scan_or_ocr_time_ms INTEGER DEFAULT 0,
  identity_parse_time_ms INTEGER DEFAULT 0,
  nim_extract_time_ms INTEGER DEFAULT 0,
  name_extract_time_ms INTEGER DEFAULT 0,
  query_time_ms INTEGER DEFAULT 0,
  verification_time_ms INTEGER DEFAULT 0,
  total_time_ms INTEGER DEFAULT 0,
  nim_expected VARCHAR(50) DEFAULT '-',
  nim_result VARCHAR(50) DEFAULT '-',
  nim_match BOOLEAN DEFAULT false,
  name_expected VARCHAR(255) DEFAULT '-',
  name_result VARCHAR(255) DEFAULT '-',
  name_match BOOLEAN DEFAULT false,
  student_found BOOLEAN DEFAULT false,
  vehicle_found BOOLEAN DEFAULT false,
  verification_status VARCHAR(50) DEFAULT 'unknown',
  result_displayed BOOLEAN DEFAULT true,
  error_message TEXT DEFAULT '',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_benchmarks_method ON public.benchmark_logs (method);
CREATE INDEX IF NOT EXISTS idx_benchmarks_created_at ON public.benchmark_logs (created_at DESC);

-- ============================================================================
-- TRIGGER: Auto-Update Kolom `updated_at`
-- ============================================================================
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_users_updated_at ON public.users;
CREATE TRIGGER trigger_users_updated_at
BEFORE UPDATE ON public.users
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS trigger_students_updated_at ON public.students;
CREATE TRIGGER trigger_students_updated_at
BEFORE UPDATE ON public.students
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS trigger_vehicles_updated_at ON public.vehicles;
CREATE TRIGGER trigger_vehicles_updated_at
BEFORE UPDATE ON public.vehicles
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();
