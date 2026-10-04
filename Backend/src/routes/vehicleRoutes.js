const express = require('express');
const { param } = require('express-validator');
const VehicleController = require('../controllers/vehicleController');
const { optionalAuth } = require('../middlewares/authMiddleware');
const validate = require('../middlewares/validateMiddleware');

const router = express.Router();

router.put(
  '/:vehicleId',
  optionalAuth,
  [param('vehicleId').notEmpty().withMessage('Vehicle ID wajib disertakan'), validate],
  VehicleController.updateVehicle
);

router.delete(
  '/:vehicleId',
  optionalAuth,
  [param('vehicleId').notEmpty().withMessage('Vehicle ID wajib disertakan'), validate],
  VehicleController.deleteVehicle
);

module.exports = router;
