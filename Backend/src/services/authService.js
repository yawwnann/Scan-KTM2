const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { query } = require('../config/db');
const config = require('../config/env');
const logger = require('../utils/logger');

class AuthService {
  /**
   * Pendaftaran akun baru (Petugas / Admin / Operator)
   */
  static async register({ email, password, name, role = 'user' }) {
    const cleanEmail = email.trim().toLowerCase();
    const cleanName = name.trim();

    // 1. Cek apakah email sudah terdaftar
    const checkUser = await query(
      'SELECT id FROM public.users WHERE email = $1',
      [cleanEmail]
    );

    if (checkUser.rows.length > 0) {
      throw new Error('Email already registered');
    }

    // 2. Hash password
    const saltRounds = 10;
    const passwordHash = await bcrypt.hash(password, saltRounds);

    // 3. Simpan ke database
    const result = await query(
      `INSERT INTO public.users (email, password_hash, name, role)
       VALUES ($1, $2, $3, $4)
       RETURNING id, email, name, role, created_at`,
      [cleanEmail, passwordHash, cleanName, role]
    );

    const user = result.rows[0];

    // 4. Generate JWT Token
    const token = jwt.sign(
      { id: user.id, email: user.email, role: user.role, name: user.name },
      config.jwtSecret,
      { expiresIn: config.jwtExpiresIn }
    );

    return {
      user: {
        id: user.id,
        email: user.email,
        name: user.name,
        role: user.role,
      },
      token,
    };
  }

  /**
   * Login pengguna menggunakan email & password
   */
  static async login({ email, password }) {
    const cleanEmail = email.trim().toLowerCase();

    // 1. Cari user berdasarkan email
    const result = await query(
      'SELECT id, email, password_hash, name, role FROM public.users WHERE email = $1',
      [cleanEmail]
    );

    if (result.rows.length === 0) {
      throw new Error('Invalid login credentials');
    }

    const user = result.rows[0];

    // 2. Validasi password
    const isMatch = await bcrypt.compare(password, user.password_hash);
    if (!isMatch) {
      throw new Error('Invalid login credentials');
    }

    // 3. Generate JWT Token
    const token = jwt.sign(
      { id: user.id, email: user.email, role: user.role, name: user.name },
      config.jwtSecret,
      { expiresIn: config.jwtExpiresIn }
    );

    return {
      token,
      user: {
        id: user.id,
        email: user.email,
        name: user.name,
        role: user.role,
      },
    };
  }

  /**
   * Ambil data profil user
   */
  static async getProfile(userId) {
    const result = await query(
      'SELECT id, email, name, role, created_at, updated_at FROM public.users WHERE id = $1',
      [userId]
    );

    return result.rows[0] || null;
  }

  /**
   * Update profil user
   */
  static async updateProfile(userId, { name }) {
    const result = await query(
      `UPDATE public.users 
       SET name = $1, updated_at = NOW()
       WHERE id = $2
       RETURNING id, email, name, role, updated_at`,
      [name.trim(), userId]
    );

    return result.rows[0] || null;
  }
}

module.exports = AuthService;
