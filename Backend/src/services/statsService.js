const { query } = require('../config/db');
const logger = require('../utils/logger');

class StatsService {
  static async getDashboardStats() {
    try {
      // 1. Total mahasiswa
      const studentsRes = await query(
        'SELECT COUNT(*) AS total FROM public.students'
      );
      const totalStudents = parseInt(studentsRes.rows[0].total, 10);

      // 2. Total kendaraan
      const vehiclesRes = await query(
        'SELECT COUNT(*) AS total FROM public.vehicles'
      );
      const totalVehicles = parseInt(vehiclesRes.rows[0].total, 10);

      // 3. Total scan
      const scansRes = await query(
        'SELECT COUNT(*) AS total FROM public.scan_history'
      );
      const totalScans = parseInt(scansRes.rows[0].total, 10);

      // 4. Scan hari ini
      const startOfToday = new Date();
      startOfToday.setHours(0, 0, 0, 0);

      const scansTodayRes = await query(
        'SELECT COUNT(*) AS total FROM public.scan_history WHERE scan_time >= $1',
        [startOfToday.toISOString()]
      );
      const scansToday = parseInt(scansTodayRes.rows[0].total, 10);

      // 5. 5 scan terakhir
      const recentScansRes = await query(
        'SELECT * FROM public.scan_history ORDER BY scan_time DESC LIMIT 5'
      );

      return {
        totalStudents,
        totalVehicles,
        totalScans,
        scansToday,
        recentScans: recentScansRes.rows,
      };
    } catch (error) {
      logger.error('Error fetching dashboard stats:', error.message);
      throw new Error(`Failed to fetch stats: ${error.message}`);
    }
  }
}

module.exports = StatsService;
