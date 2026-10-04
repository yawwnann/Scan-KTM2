const BenchmarkService = require('../services/benchmarkService');
const ApiResponse = require('../utils/apiResponse');

class BenchmarkController {
  static async createBenchmark(req, res, next) {
    try {
      const result = await BenchmarkService.createLog(req.body);
      return ApiResponse.created(res, result, 'Log benchmark berhasil disimpan');
    } catch (error) {
      next(error);
    }
  }

  static async getAllBenchmarks(req, res, next) {
    try {
      const { page = 1, limit = 50, method, start_date, end_date } = req.query;
      const result = await BenchmarkService.getAllLogs({
        page,
        limit,
        method,
        startDate: start_date,
        endDate: end_date,
      });

      return ApiResponse.success(
        res,
        result.logs,
        'Daftar log benchmark berhasil diambil',
        200,
        result.pagination
      );
    } catch (error) {
      next(error);
    }
  }

  static async exportCsv(req, res, next) {
    try {
      const csv = await BenchmarkService.exportCsv();
      const filename = `ktm_benchmark_results_${new Date().toISOString().slice(0, 10)}.csv`;

      res.setHeader('Content-Type', 'text/csv; charset=utf-8');
      res.setHeader('Content-Disposition', `attachment; filename="${filename}"`);
      return res.status(200).send(csv);
    } catch (error) {
      next(error);
    }
  }

  static async getStats(req, res, next) {
    try {
      const stats = await BenchmarkService.getStats();
      return ApiResponse.success(res, stats, 'Statistik benchmark berhasil dihitung');
    } catch (error) {
      next(error);
    }
  }

  static async clearBenchmarks(req, res, next) {
    try {
      await BenchmarkService.clearLogs();
      return ApiResponse.success(res, null, 'Seluruh log benchmark berhasil dibersihkan');
    } catch (error) {
      next(error);
    }
  }
}

module.exports = BenchmarkController;
