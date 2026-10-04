const ScanHistoryService = require('../services/scanHistoryService');
const ApiResponse = require('../utils/apiResponse');

class ScanHistoryController {
  static async getScanHistory(req, res, next) {
    try {
      const {
        page = 1,
        limit = 50,
        student_nim,
        vehicle_number,
        scan_method,
        start_date,
        end_date,
      } = req.query;

      const result = await ScanHistoryService.getScanHistory({
        page,
        limit,
        studentNim: student_nim,
        vehicleNumber: vehicle_number,
        scanMethod: scan_method,
        startDate: start_date,
        endDate: end_date,
      });

      return ApiResponse.success(
        res,
        result.history,
        'Riwayat pemindaian berhasil diambil',
        200,
        result.pagination
      );
    } catch (error) {
      next(error);
    }
  }

  static async createScanHistory(req, res, next) {
    try {
      const result = await ScanHistoryService.createScanHistory(req.body);
      return ApiResponse.created(
        res,
        result,
        'Riwayat pemindaian berhasil disimpan'
      );
    } catch (error) {
      next(error);
    }
  }

  static async batchCreate(req, res, next) {
    try {
      const { histories } = req.body;
      if (!Array.isArray(histories)) {
        return ApiResponse.badRequest(
          res,
          'Field "histories" harus berupa array data scan'
        );
      }

      const result = await ScanHistoryService.batchCreateScanHistory(histories);
      return ApiResponse.created(
        res,
        result,
        `Berhasil menyinkronkan ${result.insertedCount} riwayat pemindaian`
      );
    } catch (error) {
      next(error);
    }
  }

  static async clearScanHistory(req, res, next) {
    try {
      await ScanHistoryService.clearScanHistory();
      return ApiResponse.success(
        res,
        null,
        'Seluruh riwayat pemindaian berhasil dibersihkan'
      );
    } catch (error) {
      next(error);
    }
  }
}

module.exports = ScanHistoryController;
