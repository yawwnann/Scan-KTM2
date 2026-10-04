const { query } = require('../config/db');
const logger = require('../utils/logger');

class ScanHistoryService {
  /**
   * Mengambil riwayat scan dengan paginasi dan filter
   */
  static async getScanHistory({
    page = 1,
    limit = 50,
    studentNim = '',
    vehicleNumber = '',
    scanMethod = '',
    startDate = null,
    endDate = null,
  } = {}) {
    const parsedPage = Math.max(1, parseInt(page, 10));
    const parsedLimit = Math.max(1, Math.min(200, parseInt(limit, 10)));
    const offset = (parsedPage - 1) * parsedLimit;

    const conditions = [];
    const params = [];
    let paramIndex = 1;

    if (studentNim && studentNim.trim() !== '') {
      conditions.push(`LOWER(student_nim) = LOWER($${paramIndex})`);
      params.push(studentNim.trim());
      paramIndex++;
    }

    if (vehicleNumber && vehicleNumber.trim() !== '') {
      conditions.push(
        `UPPER(REPLACE(vehicle_number, ' ', '')) LIKE UPPER(REPLACE($${paramIndex}, ' ', ''))`
      );
      params.push(`%${vehicleNumber.trim()}%`);
      paramIndex++;
    }

    if (scanMethod && scanMethod.trim() !== '') {
      conditions.push(`scan_method = $${paramIndex}`);
      params.push(scanMethod.trim());
      paramIndex++;
    }

    if (startDate) {
      conditions.push(`scan_time >= $${paramIndex}`);
      params.push(new Date(startDate).toISOString());
      paramIndex++;
    }

    if (endDate) {
      conditions.push(`scan_time <= $${paramIndex}`);
      params.push(new Date(endDate).toISOString());
      paramIndex++;
    }

    const whereClause =
      conditions.length > 0 ? `WHERE ${conditions.join(' AND ')}` : '';

    // Count query
    const countRes = await query(
      `SELECT COUNT(*) AS total FROM public.scan_history ${whereClause}`,
      params
    );
    const totalItems = parseInt(countRes.rows[0].total, 10);

    // Data query
    const dataSql = `
      SELECT * FROM public.scan_history
      ${whereClause}
      ORDER BY scan_time DESC
      LIMIT $${paramIndex} OFFSET $${paramIndex + 1}
    `;

    const dataParams = [...params, parsedLimit, offset];
    const dataRes = await query(dataSql, dataParams);

    return {
      history: dataRes.rows,
      pagination: {
        page: parsedPage,
        limit: parsedLimit,
        totalItems,
        totalPages: Math.ceil(totalItems / parsedLimit),
      },
    };
  }

  /**
   * Simpan 1 riwayat scan baru
   */
  static async createScanHistory(historyData) {
    let scanTime = new Date().toISOString();
    if (historyData.scan_time) {
      scanTime = new Date(historyData.scan_time).toISOString();
    }

    const cleanPlate = (historyData.vehicle_number || '').trim().toUpperCase();
    const studentNim = (historyData.student_nim || '').trim() || null;

    let studentName = (historyData.student_name || '').trim();
    let faculty = (historyData.faculty || '').trim();
    let studyProgram = (historyData.study_program || '').trim();

    // Jika nama belum ada tapi NIM ada, coba lengkapi dari data mahasiswa di database
    if (studentNim && (!studentName || studentName === 'Tidak Dikenal')) {
      try {
        const sRes = await query(
          'SELECT name, faculty, study_program FROM public.students WHERE nim = $1 LIMIT 1',
          [studentNim]
        );
        if (sRes.rows.length > 0) {
          studentName = sRes.rows[0].name;
          if (!faculty) faculty = sRes.rows[0].faculty;
          if (!studyProgram) studyProgram = sRes.rows[0].study_program;
        }
      } catch (_) {}
    }

    // Resolusi vehicle_id jika belum terisi
    let vehicleId = historyData.vehicle_id || null;
    if (!vehicleId && cleanPlate) {
      try {
        const vRes = await query(
          'SELECT id FROM public.vehicles WHERE UPPER(vehicle_number) = $1 LIMIT 1',
          [cleanPlate]
        );
        if (vRes.rows.length > 0) {
          vehicleId = vRes.rows[0].id;
        }
      } catch (_) {}
    }

    const insertSql = `
      INSERT INTO public.scan_history 
        (student_nim, vehicle_id, vehicle_number, vehicle_type, student_name, faculty, study_program, scan_time, scan_method, location)
      VALUES 
        ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
      RETURNING *
    `;

    const res = await query(insertSql, [
      studentNim,
      vehicleId,
      cleanPlate,
      historyData.vehicle_type || '',
      studentName || 'Tidak Dikenal',
      faculty,
      studyProgram,
      scanTime,
      historyData.scan_method || 'barcode',
      historyData.location || 'Campus Gate',
    ]);

    return res.rows[0];
  }

  /**
   * Simpan banyak riwayat scan sekaligus (Sinkronisasi Offline SQLite Flutter)
   */
  static async batchCreateScanHistory(historiesList) {
    if (!Array.isArray(historiesList) || historiesList.length === 0) {
      return { insertedCount: 0 };
    }

    let inserted = 0;

    for (const item of historiesList) {
      try {
        let scanTime = new Date().toISOString();
        const rawTime = item.scan_time || item.scanTime;
        if (rawTime) {
          scanTime = new Date(rawTime).toISOString();
        }

        const cleanPlate = (
          item.vehicle_number ||
          item.vehicleNumber ||
          ''
        )
          .trim()
          .toUpperCase();

        const studentNim = (item.student_nim || item.studentNim || '').trim() || null;
        let studentName = (item.student_name || item.studentName || '').trim();
        let faculty = (item.faculty || '').trim();
        let studyProgram = (item.study_program || item.studyProgram || '').trim();

        if (studentNim && (!studentName || studentName === 'Tidak Dikenal')) {
          try {
            const sRes = await query(
              'SELECT name, faculty, study_program FROM public.students WHERE nim = $1 LIMIT 1',
              [studentNim]
            );
            if (sRes.rows.length > 0) {
              studentName = sRes.rows[0].name;
              if (!faculty) faculty = sRes.rows[0].faculty;
              if (!studyProgram) studyProgram = sRes.rows[0].study_program;
            }
          } catch (_) {}
        }

        let vehicleId = item.vehicle_id || null;
        if (!vehicleId && cleanPlate) {
          try {
            const vRes = await query(
              'SELECT id FROM public.vehicles WHERE UPPER(vehicle_number) = $1 LIMIT 1',
              [cleanPlate]
            );
            if (vRes.rows.length > 0) {
              vehicleId = vRes.rows[0].id;
            }
          } catch (_) {}
        }

        await query(
          `INSERT INTO public.scan_history 
             (student_nim, vehicle_id, vehicle_number, vehicle_type, student_name, faculty, study_program, scan_time, scan_method, location)
           VALUES 
             ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)`,
          [
            studentNim,
            vehicleId,
            cleanPlate,
            item.vehicle_type || item.vehicleType || '',
            studentName || 'Tidak Dikenal',
            faculty,
            studyProgram,
            scanTime,
            item.scan_method || item.scanMethod || 'unknown',
            item.location || 'Campus Gate',
          ]
        );
        inserted++;
      } catch (err) {
        logger.error('Error inserting single item in batchCreateScanHistory:', err.message);
      }
    }

    return { insertedCount: inserted };
  }

  /**
   * Bersihkan seluruh riwayat scan
   */
  static async clearScanHistory() {
    await query('TRUNCATE TABLE public.scan_history');
    return true;
  }
}

module.exports = ScanHistoryService;
