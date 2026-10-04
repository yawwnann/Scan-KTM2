const express = require('express');
const authRoutes = require('./authRoutes');
const studentRoutes = require('./studentRoutes');
const vehicleRoutes = require('./vehicleRoutes');
const scanHistoryRoutes = require('./scanHistoryRoutes');
const statsRoutes = require('./statsRoutes');
const benchmarkRoutes = require('./benchmarkRoutes');

const router = express.Router();

router.use('/auth', authRoutes);
router.use('/students', studentRoutes);
router.use('/vehicles', vehicleRoutes);
router.use('/scan-history', scanHistoryRoutes);
router.use('/stats', statsRoutes);
router.use('/benchmarks', benchmarkRoutes);

module.exports = router;
