const express = require('express');
const { body } = require('express-validator');
const ScanHistoryController = require('../controllers/scanHistoryController');
const { optionalAuth } = require('../middlewares/authMiddleware');
const validate = require('../middlewares/validateMiddleware');

const router = express.Router();

const createHistoryValidation = [
  body('vehicle_number').trim().notEmpty().withMessage('Nomor plat kendaraan wajib diisi'),
  body('student_name').trim().notEmpty().withMessage('Nama mahasiswa wajib diisi'),
  validate,
];

router.get('/', optionalAuth, ScanHistoryController.getScanHistory);
router.post(
  '/',
  optionalAuth,
  createHistoryValidation,
  ScanHistoryController.createScanHistory
);
router.post('/batch', optionalAuth, ScanHistoryController.batchCreate);
router.delete('/', optionalAuth, ScanHistoryController.clearScanHistory);

module.exports = router;
