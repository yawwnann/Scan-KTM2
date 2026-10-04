const AuthService = require('../services/authService');
const ApiResponse = require('../utils/apiResponse');

class AuthController {
  static async register(req, res, next) {
    try {
      const { email, password, name, role } = req.body;
      const result = await AuthService.register({ email, password, name, role });
      return ApiResponse.created(res, result, 'Registrasi berhasil');
    } catch (error) {
      if (error.message.includes('already registered')) {
        return ApiResponse.conflict(res, 'Email sudah terdaftar');
      }
      next(error);
    }
  }

  static async login(req, res, next) {
    try {
      const { email, password } = req.body;
      const result = await AuthService.login({ email, password });
      return ApiResponse.success(res, result, 'Login berhasil');
    } catch (error) {
      if (
        error.message.includes('Invalid login credentials') ||
        error.message.includes('invalid_grant')
      ) {
        return ApiResponse.badRequest(res, 'Email atau password salah');
      }
      next(error);
    }
  }

  static async me(req, res, next) {
    try {
      return ApiResponse.success(res, req.user, 'Profil user saat ini');
    } catch (error) {
      next(error);
    }
  }

  static async updateProfile(req, res, next) {
    try {
      const { name } = req.body;
      const updated = await AuthService.updateProfile(req.user.id, { name });
      return ApiResponse.success(res, updated, 'Profil berhasil diperbarui');
    } catch (error) {
      next(error);
    }
  }
}

module.exports = AuthController;
