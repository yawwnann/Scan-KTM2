const ApiResponse = require('../utils/apiResponse');

/**
 * Middleware untuk membatasi akses endpoint berdasarkan role
 * @param  {...string} allowedRoles Contoh: 'admin', 'operator'
 */
const requireRole = (...allowedRoles) => {
  return (req, res, next) => {
    if (!req.user) {
      return ApiResponse.unauthorized(res, 'User is not authenticated');
    }

    if (!allowedRoles.includes(req.user.role)) {
      return ApiResponse.forbidden(
        res,
        `Access denied. Required role: ${allowedRoles.join(' or ')} (Current: ${req.user.role})`
      );
    }

    next();
  };
};

const requireAdmin = requireRole('admin');

module.exports = {
  requireRole,
  requireAdmin,
};
