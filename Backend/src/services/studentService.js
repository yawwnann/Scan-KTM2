const { query } = require('../config/db');
const logger = require('../utils/logger');

class StudentService {
  /**
   * Helper format mahasiswa dengan backward-compatibility field kendaraan
   */
  static _formatStudent(student) {
    if (!student) return null;

    const vehicles = Array.isArray(student.vehicles) ? student.vehicles : [];
    const primaryVehicle =
      vehicles.find((v) => v.is_primary) || vehicles[0] || null;

    return {
      nim: student.nim,
      name: student.name,
      faculty: student.faculty,
      study_program: student.study_program,
      // Backward-compatibility untuk Flutter model lama:
      vehicle_number: primaryVehicle ? primaryVehicle.vehicle_number : '',
      vehicle_type: primaryVehicle ? primaryVehicle.vehicle_type : '',
      vehicle_brand: primaryVehicle ? primaryVehicle.vehicle_brand : '',
      // Relasi multi-kendaraan baru:
      vehicles,
      created_at: student.created_at,
      updated_at: student.updated_at,
    };
  }

  /**
   * Ambil daftar mahasiswa dengan paginasi, pencarian, dan filter
   */
  static async getAllStudents({
    page = 1,
    limit = 20,
    search = '',
    faculty = '',
    studyProgram = '',
    sortBy = 'name',
    sortOrder = 'asc',
  } = {}) {
    const parsedPage = Math.max(1, parseInt(page, 10));
    const parsedLimit = Math.max(1, Math.min(100, parseInt(limit, 10)));
    const offset = (parsedPage - 1) * parsedLimit;

    const conditions = [];
    const params = [];
    let paramIndex = 1;

    // Filter search
    if (search && search.trim() !== '') {
      conditions.push(
        `(LOWER(s.name) LIKE LOWER($${paramIndex}) OR LOWER(s.nim) LIKE LOWER($${paramIndex}))`
      );
      params.push(`%${search.trim()}%`);
      paramIndex++;
    }

    // Filter fakultas
    if (faculty && faculty.trim() !== '') {
      conditions.push(`LOWER(s.faculty) LIKE LOWER($${paramIndex})`);
      params.push(`%${faculty.trim()}%`);
      paramIndex++;
    }

    // Filter program studi
    if (studyProgram && studyProgram.trim() !== '') {
      conditions.push(`LOWER(s.study_program) LIKE LOWER($${paramIndex})`);
      params.push(`%${studyProgram.trim()}%`);
      paramIndex++;
    }

    const whereClause =
      conditions.length > 0 ? `WHERE ${conditions.join(' AND ')}` : '';

    // Hitung total items
    const countSql = `SELECT COUNT(*) AS total FROM public.students s ${whereClause}`;
    const countRes = await query(countSql, params);
    const totalItems = parseInt(countRes.rows[0].total, 10);

    // Sorting
    const allowedSortFields = ['name', 'nim', 'faculty', 'created_at', 'updated_at'];
    const safeSortBy = allowedSortFields.includes(sortBy) ? sortBy : 'name';
    const safeSortOrder = sortOrder.toLowerCase() === 'desc' ? 'DESC' : 'ASC';

    // Data query dengan json_agg multi-kendaraan
    const dataSql = `
      SELECT 
        s.nim, s.name, s.faculty, s.study_program, s.created_at, s.updated_at,
        COALESCE(
          json_agg(
            json_build_object(
              'id', v.id,
              'student_nim', v.student_nim,
              'vehicle_number', v.vehicle_number,
              'vehicle_type', v.vehicle_type,
              'vehicle_brand', v.vehicle_brand,
              'is_primary', v.is_primary,
              'notes', v.notes
            ) ORDER BY v.is_primary DESC, v.created_at ASC
          ) FILTER (WHERE v.id IS NOT NULL),
          '[]'
        ) AS vehicles
      FROM public.students s
      LEFT JOIN public.vehicles v ON s.nim = v.student_nim
      ${whereClause}
      GROUP BY s.nim
      ORDER BY s.${safeSortBy} ${safeSortOrder}
      LIMIT $${paramIndex} OFFSET $${paramIndex + 1}
    `;

    const dataParams = [...params, parsedLimit, offset];
    const dataRes = await query(dataSql, dataParams);

    const formattedData = dataRes.rows.map((row) => this._formatStudent(row));

    return {
      students: formattedData,
      pagination: {
        page: parsedPage,
        limit: parsedLimit,
        totalItems,
        totalPages: Math.ceil(totalItems / parsedLimit),
      },
    };
  }

  /**
   * Ambil detail mahasiswa berdasarkan NIM
   */
  static async getStudentByNIM(nim) {
    const cleanNim = nim.trim();

    const sql = `
      SELECT 
        s.nim, s.name, s.faculty, s.study_program, s.created_at, s.updated_at,
        COALESCE(
          json_agg(
            json_build_object(
              'id', v.id,
              'student_nim', v.student_nim,
              'vehicle_number', v.vehicle_number,
              'vehicle_type', v.vehicle_type,
              'vehicle_brand', v.vehicle_brand,
              'is_primary', v.is_primary,
              'notes', v.notes
            ) ORDER BY v.is_primary DESC, v.created_at ASC
          ) FILTER (WHERE v.id IS NOT NULL),
          '[]'
        ) AS vehicles
      FROM public.students s
      LEFT JOIN public.vehicles v ON s.nim = v.student_nim
      WHERE LOWER(s.nim) = LOWER($1)
      GROUP BY s.nim
      LIMIT 1
    `;

    const res = await query(sql, [cleanNim]);
    if (res.rows.length === 0) return null;

    return this._formatStudent(res.rows[0]);
  }

  /**
   * Cari mahasiswa berdasarkan nomor plat kendaraan
   */
  static async getStudentByVehicleNumber(vehicleNumber) {
    const cleanPlate = vehicleNumber.trim().toUpperCase();

    const sql = `
      SELECT 
        v.id AS matched_vehicle_id,
        v.vehicle_number AS matched_vehicle_number,
        v.vehicle_type AS matched_vehicle_type,
        v.vehicle_brand AS matched_vehicle_brand,
        v.is_primary AS matched_is_primary,
        s.nim, s.name, s.faculty, s.study_program, s.created_at, s.updated_at,
        (
          SELECT COALESCE(
            json_agg(
              json_build_object(
                'id', v2.id,
                'student_nim', v2.student_nim,
                'vehicle_number', v2.vehicle_number,
                'vehicle_type', v2.vehicle_type,
                'vehicle_brand', v2.vehicle_brand,
                'is_primary', v2.is_primary,
                'notes', v2.notes
              ) ORDER BY v2.is_primary DESC, v2.created_at ASC
            ),
            '[]'
          )
          FROM public.vehicles v2
          WHERE v2.student_nim = s.nim
        ) AS vehicles
      FROM public.vehicles v
      JOIN public.students s ON v.student_nim = s.nim
      WHERE UPPER(REPLACE(v.vehicle_number, ' ', '')) = UPPER(REPLACE($1, ' ', ''))
      LIMIT 1
    `;

    const res = await query(sql, [cleanPlate]);
    if (res.rows.length === 0) return null;

    const row = res.rows[0];
    const student = this._formatStudent({
      nim: row.nim,
      name: row.name,
      faculty: row.faculty,
      study_program: row.study_program,
      created_at: row.created_at,
      updated_at: row.updated_at,
      vehicles: row.vehicles,
    });

    return {
      matched_vehicle: {
        id: row.matched_vehicle_id,
        vehicle_number: row.matched_vehicle_number,
        vehicle_type: row.matched_vehicle_type,
        vehicle_brand: row.matched_vehicle_brand,
        is_primary: row.matched_is_primary,
      },
      student,
    };
  }

  /**
   * Buat data mahasiswa baru beserta kendaraan (opsional)
   */
  static async createStudent({
    nim,
    name,
    faculty,
    study_program,
    vehicle_number,
    vehicle_type,
    vehicle_brand,
    vehicles,
  }) {
    const cleanNim = nim.trim();

    // 1. Cek apakah NIM sudah ada
    const existing = await this.getStudentByNIM(cleanNim);
    if (existing) {
      throw new Error(`Student with NIM ${cleanNim} already exists`);
    }

    // 2. Insert master mahasiswa
    await query(
      `INSERT INTO public.students (nim, name, faculty, study_program)
       VALUES ($1, $2, $3, $4)`,
      [cleanNim, name.trim(), faculty.trim(), study_program.trim()]
    );

    // 3. Insert kendaraan jika diberikan
    if (Array.isArray(vehicles) && vehicles.length > 0) {
      for (let i = 0; i < vehicles.length; i++) {
        const v = vehicles[i];
        if (v.vehicle_number) {
          await query(
            `INSERT INTO public.vehicles (student_nim, vehicle_number, vehicle_type, vehicle_brand, is_primary, notes)
             VALUES ($1, $2, $3, $4, $5, $6)
             ON CONFLICT (vehicle_number) DO NOTHING`,
            [
              cleanNim,
              v.vehicle_number.trim().toUpperCase(),
              v.vehicle_type || 'Motor',
              v.vehicle_brand || '',
              v.is_primary !== undefined ? v.is_primary : i === 0,
              v.notes || '',
            ]
          );
        }
      }
    } else if (vehicle_number && vehicle_number.trim() !== '') {
      await query(
        `INSERT INTO public.vehicles (student_nim, vehicle_number, vehicle_type, vehicle_brand, is_primary)
         VALUES ($1, $2, $3, $4, $5)
         ON CONFLICT (vehicle_number) DO NOTHING`,
        [
          cleanNim,
          vehicle_number.trim().toUpperCase(),
          vehicle_type || 'Motor',
          vehicle_brand || '',
          true,
        ]
      );
    }

    return await this.getStudentByNIM(cleanNim);
  }

  /**
   * Update data profil mahasiswa
   */
  static async updateStudent(nim, updateData) {
    const cleanNim = nim.trim();
    const fields = [];
    const params = [];
    let paramIndex = 1;

    if (updateData.name !== undefined) {
      fields.push(`name = $${paramIndex}`);
      params.push(updateData.name.trim());
      paramIndex++;
    }
    if (updateData.faculty !== undefined) {
      fields.push(`faculty = $${paramIndex}`);
      params.push(updateData.faculty.trim());
      paramIndex++;
    }
    if (updateData.study_program !== undefined) {
      fields.push(`study_program = $${paramIndex}`);
      params.push(updateData.study_program.trim());
      paramIndex++;
    }

    if (fields.length > 0) {
      params.push(cleanNim);
      const sql = `
        UPDATE public.students 
        SET ${fields.join(', ')}, updated_at = NOW()
        WHERE LOWER(nim) = LOWER($${paramIndex})
      `;
      await query(sql, params);
    }

    return await this.getStudentByNIM(cleanNim);
  }

  /**
   * Hapus mahasiswa beserta seluruh kendaraannya (Cascade delete)
   */
  static async deleteStudent(nim) {
    const cleanNim = nim.trim();

    const existing = await this.getStudentByNIM(cleanNim);
    if (!existing) {
      throw new Error(`Student with NIM ${cleanNim} not found`);
    }

    await query('DELETE FROM public.students WHERE LOWER(nim) = LOWER($1)', [
      cleanNim,
    ]);
    return true;
  }

  /**
   * Bulk Upsert data mahasiswa untuk migrasi atau sinkronisasi
   */
  static async batchUpsertStudents(studentsList) {
    if (!Array.isArray(studentsList) || studentsList.length === 0) {
      return { totalStudents: 0, totalVehicles: 0 };
    }

    let insertedStudents = 0;
    let insertedVehicles = 0;

    for (const item of studentsList) {
      const nim = item.nim?.toString().trim();
      if (!nim) continue;

      const name = item.name?.toString().trim() || 'Tanpa Nama';
      const faculty = item.faculty?.toString().trim() || '-';
      const studyProgram = (
        item.study_program ||
        item.studyProgram ||
        '-'
      )
        .toString()
        .trim();

      await query(
        `INSERT INTO public.students (nim, name, faculty, study_program)
         VALUES ($1, $2, $3, $4)
         ON CONFLICT (nim) DO UPDATE 
         SET name = EXCLUDED.name, faculty = EXCLUDED.faculty, study_program = EXCLUDED.study_program`,
        [nim, name, faculty, studyProgram]
      );
      insertedStudents++;

      const plate = (
        item.vehicle_number ||
        item.vehicleNumber
      )?.toString().trim();

      if (plate) {
        await query(
          `INSERT INTO public.vehicles (student_nim, vehicle_number, vehicle_type, vehicle_brand, is_primary)
           VALUES ($1, $2, $3, $4, $5)
           ON CONFLICT (vehicle_number) DO UPDATE
           SET vehicle_type = EXCLUDED.vehicle_type, vehicle_brand = EXCLUDED.vehicle_brand`,
          [
            nim,
            plate.toUpperCase(),
            (item.vehicle_type || item.vehicleType || 'Motor').toString().trim(),
            (item.vehicle_brand || item.vehicleBrand || '').toString().trim(),
            true,
          ]
        );
        insertedVehicles++;
      }
    }

    return {
      totalStudents: insertedStudents,
      totalVehicles: insertedVehicles,
    };
  }
}

module.exports = StudentService;
