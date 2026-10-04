const express = require('express');
const { body } = require('express-validator');
const BenchmarkController = require('../controllers/benchmarkController');
const { optionalAuth } = require('../middlewares/authMiddleware');
const validate = require('../middlewares/validateMiddleware');

const router = express.Router();

const createBenchmarkValidation = [
  body('method')
    .trim()
    .notEmpty()
    .isIn(['QR', 'OCR', 'qr', 'ocr'])
    .withMessage('Method harus QR atau OCR'),
  body('total_time_ms')
    .isInt({ min: 0 })
    .withMessage('total_time_ms harus berupa angka positif'),
  validate,
];

// 1. Ekspor CSV (Dapat diakses langsung via browser untuk download file Bab 4)
router.get('/export-csv', optionalAuth, BenchmarkController.exportCsv);

// 2. Statistik kalkulasi performa
router.get('/stats', optionalAuth, BenchmarkController.getStats);

// 3. Simpan log benchmark baru
router.post(
  '/',
  optionalAuth,
  createBenchmarkValidation,
  BenchmarkController.createBenchmark
);

// 4. Daftar log benchmark
router.get('/', optionalAuth, BenchmarkController.getAllBenchmarks);

// 5. Bersihkan seluruh log benchmark
router.delete('/', optionalAuth, BenchmarkController.clearBenchmarks);

module.exports = router;
