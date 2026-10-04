const VehicleService = require('../services/vehicleService');
const ApiResponse = require('../utils/apiResponse');

class VehicleController {
  static async getVehiclesByStudent(req, res, next) {
    try {
      const { nim } = req.params;
      const vehicles = await VehicleService.getVehiclesByStudent(nim);
      return ApiResponse.success(res, vehicles, `Kendaraan untuk mahasiswa ${nim}`);
    } catch (error) {
      next(error);
    }
  }

  static async addVehicle(req, res, next) {
    try {
      const { nim } = req.params;
      const { vehicle_number, vehicle_type, vehicle_brand, is_primary, notes } = req.body;

      const newVehicle = await VehicleService.addVehicle(nim, {
        vehicle_number,
        vehicle_type,
        vehicle_brand,
        is_primary,
        notes,
      });

      return ApiResponse.created(res, newVehicle, 'Kendaraan berhasil ditambahkan');
    } catch (error) {
      if (
        error.message.includes('sudah terdaftar') ||
        error.message.includes('already exists')
      ) {
        return ApiResponse.conflict(res, error.message);
      }
      if (error.message.includes('tidak ditemukan')) {
        return ApiResponse.notFound(res, error.message);
      }
      next(error);
    }
  }

  static async updateVehicle(req, res, next) {
    try {
      const { vehicleId } = req.params;
      const updatedVehicle = await VehicleService.updateVehicle(vehicleId, req.body);
      return ApiResponse.success(res, updatedVehicle, 'Data kendaraan berhasil diperbarui');
    } catch (error) {
      if (error.message.includes('sudah terdaftar')) {
        return ApiResponse.conflict(res, error.message);
      }
      if (error.message.includes('tidak ditemukan')) {
        return ApiResponse.notFound(res, error.message);
      }
      next(error);
    }
  }

  static async deleteVehicle(req, res, next) {
    try {
      const { vehicleId } = req.params;
      await VehicleService.deleteVehicle(vehicleId);
      return ApiResponse.success(res, null, 'Kendaraan berhasil dihapus');
    } catch (error) {
      if (error.message.includes('tidak ditemukan')) {
        return ApiResponse.notFound(res, error.message);
      }
      next(error);
    }
  }
}

module.exports = VehicleController;
