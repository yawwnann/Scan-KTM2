import 'dart:async';
import '../models/student.dart';
import '../models/scan_history.dart';
import '../config/app_config.dart';
import '../data/demo_data.dart';
import '../utils/logging/logger.dart';
import 'api_service.dart';
import 'local_database_service.dart';
import 'sync_service.dart';

class StudentService {
  static final LocalDatabaseService _localDb = LocalDatabaseService();
  static final SyncService _syncService = SyncService();

  // Fungsi untuk mendapatkan data mahasiswa berdasarkan barcode
  static Future<Student?> getStudentByBarcode(String barcode) async {
    if (AppConfig.isDevelopment) {
      return DemoData.findStudentByBarcode(barcode);
    }
    return await getStudentByNIM(barcode);
  }

  // Fungsi untuk mendapatkan data mahasiswa berdasarkan NIM
  // Menggunakan arsitektur Offline-First (SQLite first -> Fallback ke Express & Supabase Backend)
  static Future<Student?> getStudentByNIM(String nim) async {
    if (AppConfig.isDevelopment) {
      return DemoData.findStudentByNIM(nim);
    }

    try {
      // 1. Cek database lokal SQLite (Ultra cepat, < 10ms)
      final localStudent = await _localDb.getStudentByNIM(nim);
      if (localStudent != null) {
        Logger.info('Student found in local SQLite: ${localStudent.name} ($nim)');
        return localStudent;
      }

      // 2. Fallback ke Backend Express & Supabase jika data lokal belum ada
      Logger.info('Student not in SQLite. Falling back to Backend for NIM: $nim');
      final remoteStudent = await ApiService.getStudentByNIM(nim);

      if (remoteStudent != null) {
        // Simpan ke SQLite lokal agar query berikutnya instan (Read-Through Caching)
        unawaited(_localDb.insertOrUpdateStudent(remoteStudent));
        return remoteStudent;
      }

      return null;
    } catch (e) {
      Logger.error('Error in StudentService.getStudentByNIM: $e');
      return null;
    }
  }

  // Fungsi untuk mendapatkan data mahasiswa berdasarkan nomor plat
  // Menggunakan arsitektur Offline-First (SQLite first -> Fallback ke Backend)
  static Future<Student?> getStudentByVehicleNumber(
    String vehicleNumber,
  ) async {
    if (AppConfig.isDevelopment) {
      return DemoData.findStudentByVehicleNumber(vehicleNumber);
    }

    try {
      // 1. Cek database lokal SQLite (memanfaatkan index plat kendaraan)
      final localStudent =
          await _localDb.getStudentByVehicleNumber(vehicleNumber);
      if (localStudent != null) {
        Logger.info(
          'Student found in local SQLite by plate: ${localStudent.name} ($vehicleNumber)',
        );
        return localStudent;
      }

      // 2. Fallback ke Backend jika belum ada di lokal
      Logger.info(
        'Student not in SQLite. Falling back to Backend for plate: $vehicleNumber',
      );
      final remoteStudent =
          await ApiService.getStudentByVehicleNumber(vehicleNumber);

      if (remoteStudent != null) {
        // Cache ke SQLite
        unawaited(_localDb.insertOrUpdateStudent(remoteStudent));
        return remoteStudent;
      }

      return null;
    } catch (e) {
      Logger.error('Error in StudentService.getStudentByVehicleNumber: $e');
      return null;
    }
  }

  // Fungsi untuk menyimpan riwayat scanning
  // Disimpan ke SQLite lokal terlebih dahulu agar tidak pernah hilang jika offline,
  // lalu diunggah ke Backend secara asinkron di latar belakang.
  static Future<bool> saveScanHistory(
    Student student, {
    String scanMethod = 'unknown',
  }) async {
    if (AppConfig.isDevelopment) {
      DemoData.addScanHistory(student, scanMethod);
      Logger.info(
        'Demo mode: Data scanning disimpan untuk ${student.name} via $scanMethod',
      );
      return true;
    }

    try {
      // 1. Buat object riwayat scan
      final history = ScanHistory.fromStudent(
        student,
        scanMethod: scanMethod,
        location: 'Campus Gate',
      );

      // 2. Simpan ke SQLite lokal (status is_synced: false)
      await _localDb.insertScanHistory(history, isSynced: false);
      Logger.info('Scan history saved to local SQLite for ${student.name}');

      // 3. Trigger upload ke Backend secara non-blocking di background
      unawaited(_syncService.pushPendingScanHistories());

      return true;
    } catch (e) {
      Logger.error('Error in StudentService.saveScanHistory: $e');
      // Fallback langsung ke Backend jika SQLite mengalami masalah
      return await ApiService.saveScanHistory(
        student,
        'Campus Gate',
        scanMethod: scanMethod,
      );
    }
  }

  // Fungsi untuk mendapatkan riwayat scan
  static Future<List<Student>> getScanHistory() async {
    if (AppConfig.isDevelopment) {
      return DemoData.getScanHistoryAsStudents();
    }

    try {
      // Cek riwayat dari SQLite lokal terlebih dahulu
      final localHistories = await _localDb.getAllScanHistories(limit: 100);
      if (localHistories.isNotEmpty) {
        return localHistories.map((h) => h.toStudent()).toList();
      }

      // Fallback ke Backend jika riwayat lokal masih kosong
      final remoteList = await ApiService.getScanHistoryAsStudents();
      return remoteList;
    } catch (e) {
      Logger.error('Error in StudentService.getScanHistory: $e');
      return await ApiService.getScanHistoryAsStudents();
    }
  }
}
