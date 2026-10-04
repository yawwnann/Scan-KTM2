const { query } = require('../config/db');
const logger = require('../utils/logger');

class BenchmarkService {
  /**
   * Header CSV standar untuk pengujian performa skripsi Bab 4
   */
  static get CSV_HEADER() {
    return 'run_id,timestamp,method,image_load_time_ms,scan_or_ocr_time_ms,identity_parse_time_ms,nim_extract_time_ms,name_extract_time_ms,firebase_query_time_ms,verification_time_ms,total_time_ms,nim_expected,nim_result,nim_match,name_expected,name_result,name_match,student_found,vehicle_found,verification_status,result_displayed,error_message';
  }

  /**
   * Rekam 1 log pengujian performa baru
   */
  static async createLog(data) {
    const method = (data.method || 'QR').toUpperCase();
    const runId = data.run_id || `${method}-${Date.now().toString().slice(-4)}`;

    const insertSql = `
      INSERT INTO public.benchmark_logs (
        run_id, method, image_load_time_ms, scan_or_ocr_time_ms, identity_parse_time_ms,
        nim_extract_time_ms, name_extract_time_ms, query_time_ms, verification_time_ms,
        total_time_ms, nim_expected, nim_result, nim_match, name_expected,
        name_result, name_match, student_found, vehicle_found, verification_status,
        result_displayed, error_message, created_at
      ) VALUES (
        $1, $2, $3, $4, $5, $6, $7, $8, $9, $10,
        $11, $12, $13, $14, $15, $16, $17, $18, $19, $20, $21, $22
      ) RETURNING *
    `;

    const createdAt = data.timestamp
      ? new Date(data.timestamp).toISOString()
      : new Date().toISOString();

    const params = [
      runId,
      method,
      data.image_load_time_ms || 0,
      data.scan_or_ocr_time_ms || 0,
      data.identity_parse_time_ms || 0,
      data.nim_extract_time_ms || 0,
      data.name_extract_time_ms || 0,
      data.query_time_ms || data.firebase_query_time_ms || 0,
      data.verification_time_ms || 0,
      data.total_time_ms || 0,
      data.nim_expected || '-',
      data.nim_result || '-',
      Boolean(data.nim_match),
      data.name_expected || '-',
      data.name_result || '-',
      Boolean(data.name_match),
      Boolean(data.student_found),
      Boolean(data.vehicle_found),
      data.verification_status || 'unknown',
      data.result_displayed !== undefined ? Boolean(data.result_displayed) : true,
      data.error_message || '',
      createdAt,
    ];

    const res = await query(insertSql, params);
    return res.rows[0];
  }

  /**
   * Ambil daftar seluruh log benchmark
   */
  static async getAllLogs({
    page = 1,
    limit = 50,
    method = '',
    startDate = null,
    endDate = null,
  } = {}) {
    const parsedPage = Math.max(1, parseInt(page, 10));
    const parsedLimit = Math.max(1, Math.min(500, parseInt(limit, 10)));
    const offset = (parsedPage - 1) * parsedLimit;

    const conditions = [];
    const params = [];
    let paramIndex = 1;

    if (method && method.trim() !== '') {
      conditions.push(`method = $${paramIndex}`);
      params.push(method.trim().toUpperCase());
      paramIndex++;
    }

    if (startDate) {
      conditions.push(`created_at >= $${paramIndex}`);
      params.push(new Date(startDate).toISOString());
      paramIndex++;
    }

    if (endDate) {
      conditions.push(`created_at <= $${paramIndex}`);
      params.push(new Date(endDate).toISOString());
      paramIndex++;
    }

    const whereClause =
      conditions.length > 0 ? `WHERE ${conditions.join(' AND ')}` : '';

    const countRes = await query(
      `SELECT COUNT(*) AS total FROM public.benchmark_logs ${whereClause}`,
      params
    );
    const totalItems = parseInt(countRes.rows[0].total, 10);

    const dataSql = `
      SELECT * FROM public.benchmark_logs
      ${whereClause}
      ORDER BY created_at DESC
      LIMIT $${paramIndex} OFFSET $${paramIndex + 1}
    `;

    const dataRes = await query(dataSql, [...params, parsedLimit, offset]);

    return {
      logs: dataRes.rows,
      pagination: {
        page: parsedPage,
        limit: parsedLimit,
        totalItems,
        totalPages: Math.ceil(totalItems / parsedLimit),
      },
    };
  }

  /**
   * Ekspor seluruh data benchmark ke format string CSV untuk Bab 4
   */
  static async exportCsv() {
    const sql = `
      SELECT * FROM public.benchmark_logs
      ORDER BY created_at ASC
    `;
    const res = await query(sql);
    const rows = res.rows;

    const csvLines = [this.CSV_HEADER];

    rows.forEach((r) => {
      const cleanError = (r.error_message || '').replace(/[,\n\r]/g, ' ');
      const line = [
        r.run_id,
        new Date(r.created_at).toISOString(),
        r.method,
        r.image_load_time_ms,
        r.scan_or_ocr_time_ms,
        r.identity_parse_time_ms,
        r.nim_extract_time_ms,
        r.name_extract_time_ms,
        r.query_time_ms,
        r.verification_time_ms,
        r.total_time_ms,
        `"${r.nim_expected}"`,
        `"${r.nim_result}"`,
        r.nim_match,
        `"${r.name_expected}"`,
        `"${r.name_result}"`,
        r.name_match,
        r.student_found,
        r.vehicle_found,
        r.verification_status,
        r.result_displayed,
        `"${cleanError}"`,
      ].join(',');

      csvLines.push(line);
    });

    return csvLines.join('\n');
  }

  /**
   * Ringkasan statistik performa untuk analisis Skripsi
   */
  static async getStats() {
    const qrStatsSql = `
      SELECT 
        COUNT(*) AS total_runs,
        ROUND(AVG(scan_or_ocr_time_ms), 2) AS avg_scan_time_ms,
        ROUND(AVG(identity_parse_time_ms), 2) AS avg_parse_time_ms,
        ROUND(AVG(query_time_ms), 2) AS avg_query_time_ms,
        ROUND(AVG(verification_time_ms), 2) AS avg_verification_time_ms,
        ROUND(AVG(total_time_ms), 2) AS avg_total_time_ms,
        COUNT(*) FILTER (WHERE verification_status = 'valid') AS valid_count,
        COUNT(*) FILTER (WHERE verification_status != 'valid') AS invalid_count
      FROM public.benchmark_logs
      WHERE method = 'QR'
    `;

    const ocrStatsSql = `
      SELECT 
        COUNT(*) AS total_runs,
        ROUND(AVG(image_load_time_ms), 2) AS avg_image_load_time_ms,
        ROUND(AVG(scan_or_ocr_time_ms), 2) AS avg_ocr_process_time_ms,
        ROUND(AVG(nim_extract_time_ms), 2) AS avg_nim_extract_time_ms,
        ROUND(AVG(name_extract_time_ms), 2) AS avg_name_extract_time_ms,
        ROUND(AVG(query_time_ms), 2) AS avg_query_time_ms,
        ROUND(AVG(verification_time_ms), 2) AS avg_verification_time_ms,
        ROUND(AVG(total_time_ms), 2) AS avg_total_time_ms,
        COUNT(*) FILTER (WHERE nim_match = true) AS nim_match_count,
        COUNT(*) FILTER (WHERE name_match = true) AS name_match_count,
        COUNT(*) FILTER (WHERE verification_status = 'valid') AS valid_count
      FROM public.benchmark_logs
      WHERE method = 'OCR'
    `;

    const qrRes = await query(qrStatsSql);
    const ocrRes = await query(ocrStatsSql);

    return {
      qr: qrRes.rows[0],
      ocr: ocrRes.rows[0],
    };
  }

  /**
   * Kosongkan tabel benchmark
   */
  static async clearLogs() {
    await query('TRUNCATE TABLE public.benchmark_logs');
    return true;
  }
}

module.exports = BenchmarkService;
