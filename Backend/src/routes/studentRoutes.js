const express = require('express');
const { body, param } = require('express-validator');
const StudentController = require('../controllers/studentController');
const VehicleController = require('../controllers/vehicleController');
const { optionalAuth, requireAuth } = require('../middlewares/authMiddleware');
const { requireAdmin } = require('../middlewares/roleMiddleware');
const validate = require('../middlewares/validateMiddleware');

const router = express.Router();

// Validation Rules
const createStudentValidation = [
  body('nim').trim().notEmpty().withMessage('NIM wajib diisi'),
  body('name').trim().notEmpty().withMessage('Nama mahasiswa wajib diisi'),
  body('faculty').trim().notEmpty().withMessage('Fakultas wajib diisi'),
  body('study_program')
    .trim()
    .notEmpty()
    .withMessage('Program studi wajib diisi'),
  validate,
];

const addVehicleValidation = [
  param('nim').trim().notEmpty().withMessage('NIM mahasiswa wajib diisi'),
  body('vehicle_number')
    .trim()
    .notEmpty()
    .withMessage('Nomor plat kendaraan wajib diisi'),
  body('vehicle_type')
    .optional()
    .trim()
    .notEmpty()
    .withMessage('Tipe kendaraan tidak boleh kosong'),
  validate,
];

// 1. Lookup plat nomor kendaraan
router.get(
  '/vehicle/:vehicleNumber',
  optionalAuth,
  StudentController.getStudentByVehicleNumber
);

// 2. Multi-kendaraan untuk mahasiswa tertentu
router.get(
  '/:nim/vehicles',
  optionalAuth,
  VehicleController.getVehiclesByStudent
);

router.post(
  '/:nim/vehicles',
  optionalAuth, // Fleksibel: dapat diproteksi requireAuth & requireAdmin jika sistem sudah live
  addVehicleValidation,
  VehicleController.addVehicle
);

// 3. Batch sinkronisasi mahasiswa
router.post(
  '/batch',
  optionalAuth,
  StudentController.batchUpsert
);

// 4. Detail mahasiswa berdasarkan NIM
router.get('/:nim', optionalAuth, StudentController.getStudentByNIM);

// 5. Update data mahasiswa
router.put('/:nim', optionalAuth, StudentController.updateStudent);

// 6. Hapus mahasiswa
router.delete('/:nim', optionalAuth, StudentController.deleteStudent);

// 7. Ambil daftar seluruh mahasiswa (dengan search & filter)
router.get('/', optionalAuth, StudentController.getAllStudents);

// 8. Buat mahasiswa baru
router.post(
  '/',
  optionalAuth,
  createStudentValidation,
  StudentController.createStudent
);

module.exports = router;
