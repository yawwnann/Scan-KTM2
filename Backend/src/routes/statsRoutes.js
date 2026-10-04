const express = require('express');
const StatsController = require('../controllers/statsController');
const { optionalAuth } = require('../middlewares/authMiddleware');

const router = express.Router();

router.get('/', optionalAuth, StatsController.getStats);

module.exports = router;
