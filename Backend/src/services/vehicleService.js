const { query } = require('../config/db');
const logger = require('../utils/logger');

class VehicleService {
  /**
   * Ambil semua kendaraan milik seorang mahasiswa
   */
  static async getVehiclesByStudent(nim) {
    const cleanNim = nim.trim();
    const res = await query(
      `SELECT * FROM public.vehicles 
       WHERE LOWER(student_nim) = LOWER($1) 
       ORDER BY is_primary DESC, created_at ASC`,
      [cleanNim]
    );

    return res.rows;
  }

  /**
   * Tambah kendaraan baru ke mahasiswa yang sudah ada
   */
  static async addVehicle(studentNim, vehicleData) {
    const cleanNim = studentNim.trim();
    const cleanPlate = vehicleData.vehicle_number.trim().toUpperCase();

    // 1. Pastikan mahasiswa terdaftar
    const studentRes = await query(
      'SELECT nim FROM public.students WHERE LOWER(nim) = LOWER($1)',
      [cleanNim]
    );

    if (studentRes.rows.length === 0) {
      throw new Error(`Mahasiswa dengan NIM ${cleanNim} tidak ditemukan`);
    }

    // 2. Pastikan plat nomor belum dipakai kendaraan lain
    const plateRes = await query(
      'SELECT id, student_nim FROM public.vehicles WHERE UPPER(vehicle_number) = $1',
      [cleanPlate]
    );

    if (plateRes.rows.length > 0) {
      throw new Error(
        `Plat nomor ${cleanPlate} sudah terdaftar atas NIM ${plateRes.rows[0].student_nim}`
      );
    }

    // 3. Jika diset is_primary, lepas is_primary dari kendaraan lain milik mahasiswa ini
    if (vehicleData.is_primary) {
      await query(
        'UPDATE public.vehicles SET is_primary = false WHERE LOWER(student_nim) = LOWER($1)',
        [cleanNim]
      );
    }

    // 4. Insert kendaraan baru
    const insertRes = await query(
      `INSERT INTO public.vehicles (student_nim, vehicle_number, vehicle_type, vehicle_brand, is_primary, notes)
       VALUES ($1, $2, $3, $4, $5, $6)
       RETURNING *`,
      [
        cleanNim,
        cleanPlate,
        vehicleData.vehicle_type || 'Motor',
        vehicleData.vehicle_brand || '',
        vehicleData.is_primary || false,
        vehicleData.notes || '',
      ]
    );

    return insertRes.rows[0];
  }

  /**
   * Update data kendaraan berdasarkan ID
   */
  static async updateVehicle(vehicleId, updateData) {
    // 1. Cari kendaraan saat ini
    const curRes = await query(
      'SELECT * FROM public.vehicles WHERE id = $1',
      [vehicleId]
    );

    if (curRes.rows.length === 0) {
      throw new Error('Kendaraan tidak ditemukan');
    }

    const currentVehicle = curRes.rows[0];
    const fields = [];
    const params = [];
    let paramIndex = 1;

    if (updateData.vehicle_number) {
      const cleanPlate = updateData.vehicle_number.trim().toUpperCase();
      const conflictRes = await query(
        'SELECT id FROM public.vehicles WHERE UPPER(vehicle_number) = $1 AND id != $2',
        [cleanPlate, vehicleId]
      );

      if (conflictRes.rows.length > 0) {
        throw new Error(`Plat nomor ${cleanPlate} sudah terdaftar pada data lain`);
      }

      fields.push(`vehicle_number = $${paramIndex}`);
      params.push(cleanPlate);
      paramIndex++;
    }

    if (updateData.vehicle_type !== undefined) {
      fields.push(`vehicle_type = $${paramIndex}`);
      params.push(updateData.vehicle_type.trim());
      paramIndex++;
    }

    if (updateData.vehicle_brand !== undefined) {
      fields.push(`vehicle_brand = $${paramIndex}`);
      params.push(updateData.vehicle_brand.trim());
      paramIndex++;
    }

    if (updateData.notes !== undefined) {
      fields.push(`notes = $${paramIndex}`);
      params.push(updateData.notes.trim());
      paramIndex++;
    }

    if (updateData.is_primary === true) {
      // Lepaskan primary kendaraan lain
      await query(
        'UPDATE public.vehicles SET is_primary = false WHERE student_nim = $1',
        [currentVehicle.student_nim]
      );
      fields.push(`is_primary = $${paramIndex}`);
      params.push(true);
      paramIndex++;
    } else if (updateData.is_primary === false) {
      fields.push(`is_primary = $${paramIndex}`);
      params.push(false);
      paramIndex++;
    }

    if (fields.length === 0) {
      return currentVehicle;
    }

    params.push(vehicleId);
    const sql = `
      UPDATE public.vehicles 
      SET ${fields.join(', ')}, updated_at = NOW()
      WHERE id = $${paramIndex}
      RETURNING *
    `;

    const updateRes = await query(sql, params);
    return updateRes.rows[0];
  }

  /**
   * Hapus kendaraan berdasarkan ID
   */
  static async deleteVehicle(vehicleId) {
    const res = await query(
      'DELETE FROM public.vehicles WHERE id = $1 RETURNING id',
      [vehicleId]
    );

    if (res.rows.length === 0) {
      throw new Error('Kendaraan tidak ditemukan');
    }

    return true;
  }
}

module.exports = VehicleService;
