const StatsService = require('../services/statsService');
const ApiResponse = require('../utils/apiResponse');

class StatsController {
  static async getStats(req, res, next) {
    try {
      const stats = await StatsService.getDashboardStats();
      return ApiResponse.success(res, stats, 'Statistik sistem berhasil diambil');
    } catch (error) {
      next(error);
    }
  }
}

module.exports = StatsController;
