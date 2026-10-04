const express = require('express');
const { body } = require('express-validator');
const AuthController = require('../controllers/authController');
const { requireAuth } = require('../middlewares/authMiddleware');
const validate = require('../middlewares/validateMiddleware');

const router = express.Router();

// Validation Rules
const registerValidation = [
  body('email').isEmail().withMessage('Email tidak valid'),
  body('password')
    .isLength({ min: 6 })
    .withMessage('Password minimal 6 karakter'),
  body('name').trim().notEmpty().withMessage('Nama wajib diisi'),
  body('role')
    .optional()
    .isIn(['admin', 'user', 'operator'])
    .withMessage('Role tidak valid'),
  validate,
];

const loginValidation = [
  body('email').isEmail().withMessage('Email tidak valid'),
  body('password').notEmpty().withMessage('Password wajib diisi'),
  validate,
];

// Endpoints
router.post('/register', registerValidation, AuthController.register);
router.post('/login', loginValidation, AuthController.login);
router.get('/me', requireAuth, AuthController.me);
router.put(
  '/profile',
  requireAuth,
  [body('name').trim().notEmpty().withMessage('Nama wajib diisi'), validate],
  AuthController.updateProfile
);

module.exports = router;
