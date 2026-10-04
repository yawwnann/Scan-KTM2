const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const config = require('./config/env');
const apiRoutes = require('./routes');
const { notFoundHandler, errorHandler } = require('./middlewares/errorMiddleware');
const ApiResponse = require('./utils/apiResponse');

const app = express();

// Security Middlewares
app.use(helmet());
app.use(
  cors({
    origin: config.corsOrigin === '*' ? true : config.corsOrigin,
    credentials: true,
  })
);

// Request Logger
if (config.nodeEnv !== 'test') {
  app.use(morgan(config.isDev ? 'dev' : 'combined'));
}

// Body Parsers
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Health Check
app.get('/health', (req, res) => {
  return ApiResponse.success(res, {
    status: 'healthy',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    version: '1.0.0',
    environment: config.nodeEnv,
  }, 'STNK Check UAD API is running');
});

// Root Information
app.get('/', (req, res) => {
  return ApiResponse.success(res, {
    service: 'STNK Check UAD - Express.js & Supabase Backend',
    version: '1.0.0',
    documentation: '/api/v1',
    health: '/health',
  }, 'Welcome to STNK Check UAD Backend API');
});

// API Routes
// Dukung baik /api/v1 maupun /api (agar kompatibel langsung dengan AppConfig.baseUrl di Flutter)
app.use('/api/v1', apiRoutes);
app.use('/api', apiRoutes);

// Error Handling Middlewares
app.use(notFoundHandler);
app.use(errorHandler);

module.exports = app;
