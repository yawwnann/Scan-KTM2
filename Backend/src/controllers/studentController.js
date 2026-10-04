const StudentService = require('../services/studentService');
const ApiResponse = require('../utils/apiResponse');

class StudentController {
  static async getAllStudents(req, res, next) {
    try {
      const {
        page = 1,
        limit = 20,
        search = '',
        faculty = '',
        study_program = '',
        sort_by = 'name',
        sort_order = 'asc',
      } = req.query;

      const result = await StudentService.getAllStudents({
        page,
        limit,
        search,
        faculty,
        studyProgram: study_program,
        sortBy: sort_by,
        sortOrder: sort_order,
      });

      return ApiResponse.success(
        res,
        result.students,
        'Daftar mahasiswa berhasil diambil',
        200,
        result.pagination
      );
    } catch (error) {
      next(error);
    }
  }

  static async getStudentByNIM(req, res, next) {
    try {
      const { nim } = req.params;
      const student = await StudentService.getStudentByNIM(nim);

      if (!student) {
        return ApiResponse.notFound(
          res,
          `Data mahasiswa dengan NIM/Barcode ${nim} tidak ditemukan`
        );
      }

      return ApiResponse.success(res, student, 'Data mahasiswa ditemukan');
    } catch (error) {
      next(error);
    }
  }

  static async getStudentByVehicleNumber(req, res, next) {
    try {
      const { vehicleNumber } = req.params;
      const result = await StudentService.getStudentByVehicleNumber(vehicleNumber);

      if (!result) {
        return ApiResponse.notFound(
          res,
          `Kendaraan dengan plat ${vehicleNumber} tidak terdaftar dalam sistem`
        );
      }

      return ApiResponse.success(
        res,
        result,
        'Data mahasiswa pemilik kendaraan berhasil ditemukan'
      );
    } catch (error) {
      next(error);
    }
  }

  static async createStudent(req, res, next) {
    try {
      const {
        nim,
        name,
        faculty,
        study_program,
        vehicle_number,
        vehicle_type,
        vehicle_brand,
        vehicles,
      } = req.body;

      const newStudent = await StudentService.createStudent({
        nim,
        name,
        faculty,
        study_program,
        vehicle_number,
        vehicle_type,
        vehicle_brand,
        vehicles,
      });

      return ApiResponse.created(
        res,
        newStudent,
        'Data mahasiswa berhasil didaftarkan'
      );
    } catch (error) {
      if (error.message.includes('already exists')) {
        return ApiResponse.conflict(res, error.message);
      }
      next(error);
    }
  }

  static async updateStudent(req, res, next) {
    try {
      const { nim } = req.params;
      const updatedStudent = await StudentService.updateStudent(nim, req.body);

      if (!updatedStudent) {
        return ApiResponse.notFound(
          res,
          `Mahasiswa dengan NIM ${nim} tidak ditemukan`
        );
      }

      return ApiResponse.success(
        res,
        updatedStudent,
        'Data mahasiswa berhasil diperbarui'
      );
    } catch (error) {
      next(error);
    }
  }

  static async deleteStudent(req, res, next) {
    try {
      const { nim } = req.params;
      await StudentService.deleteStudent(nim);
      return ApiResponse.success(
        res,
        null,
        `Data mahasiswa ${nim} berhasil dihapus`
      );
    } catch (error) {
      if (error.message.includes('not found')) {
        return ApiResponse.notFound(res, error.message);
      }
      next(error);
    }
  }

  static async batchUpsert(req, res, next) {
    try {
      const { students } = req.body;
      if (!Array.isArray(students)) {
        return ApiResponse.badRequest(res, 'Field "students" harus berupa array');
      }

      const result = await StudentService.batchUpsertStudents(students);
      return ApiResponse.success(
        res,
        result,
        `Berhasil menyinkronkan ${result.totalStudents} data mahasiswa`
      );
    } catch (error) {
      next(error);
    }
  }
}

module.exports = StudentController;
