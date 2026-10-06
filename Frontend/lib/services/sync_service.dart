import 'dart:async';
import 'local_database_service.dart';
import 'api_service.dart';
import '../utils/logging/logger.dart';

class SyncResult {
  final bool success;
  final int studentsSynced;
  final int scanHistorySynced;
  final String message;

  SyncResult({
    required this.success,
    required this.studentsSynced,
    required this.scanHistorySynced,
    required this.message,
  });
}

class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  final LocalDatabaseService _localDb = LocalDatabaseService();
  bool _isSyncing = false;

  bool get isSyncing => _isSyncing;

  /// Sinkronisasi menyeluruh: Upload riwayat scan tertunda & Download master data mahasiswa
  Future<SyncResult> syncAll() async {
    if (_isSyncing) {
      return SyncResult(
        success: false,
        studentsSynced: 0,
        scanHistorySynced: 0,
        message: 'Sinkronisasi sedang berjalan.',
      );
    }

    _isSyncing = true;
    Logger.info('Starting full sync (SQLite <-> Firebase)...');

    int uploadedHistoryCount = 0;
    int downloadedStudentCount = 0;

    try {
      // 1. Upload scan history yang belum ter-sync
      uploadedHistoryCount = await pushPendingScanHistories();

      // 2. Download master data mahasiswa dari Firebase
      downloadedStudentCount = await pullStudentsFromFirebase();

      // 3. Catat waktu sinkronisasi terakhir
      final nowStr = DateTime.now().toIso8601String();
      await _localDb.setMetadata('last_sync_timestamp', nowStr);
      await _localDb.setMetadata(
        'total_students_count',
        downloadedStudentCount.toString(),
      );

      _isSyncing = false;
      return SyncResult(
        success: true,
        studentsSynced: downloadedStudentCount,
        scanHistorySynced: uploadedHistoryCount,
        message:
            'Sinkronisasi sukses! $downloadedStudentCount mahasiswa disinkronkan, $uploadedHistoryCount riwayat diunggah.',
      );
    } catch (e) {
      _isSyncing = false;
      Logger.error('Full sync failed: $e');
      return SyncResult(
        success: false,
        studentsSynced: downloadedStudentCount,
        scanHistorySynced: uploadedHistoryCount,
        message: 'Sinkronisasi gagal: $e',
      );
    }
  }

  /// Download data mahasiswa dari Backend ke SQLite lokal
  Future<int> pullStudentsFromFirebase() async {
    try {
      Logger.info('Pulling students from Backend Express & Supabase...');
      final students = await ApiService.getAllStudents(limit: 2000);

      // Sinkronkan penuh dengan data backend (jika backend kosong, kosongkan juga di SQLite)
      await _localDb.replaceAllStudents(students);
      Logger.info('Successfully synced ${students.length} students to SQLite');
      return students.length;
    } catch (e) {
      Logger.error('Error pulling students from Backend: $e');
      rethrow;
    }
  }

  /// Kosongkan database lokal SQLite (cache mahasiswa & riwayat)
  Future<void> clearLocalDatabase() async {
    await _localDb.clearAll();
  }

  /// Upload riwayat scan lokal yang berstatus is_synced == 0 ke Backend
  Future<int> pushPendingScanHistories() async {
    try {
      final unsynced = await _localDb.getUnsyncedScanHistories();
      if (unsynced.isEmpty) return 0;

      Logger.info('Uploading ${unsynced.length} pending scan histories via batch...');
      final success = await ApiService.batchSyncScanHistories(unsynced);

      if (success) {
        final syncedIds = unsynced.map((h) => h.id).toList();
        await _localDb.markScanHistoriesAsSynced(syncedIds);
        Logger.info('Successfully marked ${syncedIds.length} histories as synced');
        return syncedIds.length;
      } else {
        // Fallback per-item jika batch mengalami kendala
        final syncedIds = <String>[];
        for (final history in unsynced) {
          try {
            final student = history.toStudent();
            final itemSuccess = await ApiService.saveScanHistory(
              student,
              history.location,
              scanMethod: history.scanMethod,
            );
            if (itemSuccess) {
              syncedIds.add(history.id);
            }
          } catch (e) {
            Logger.error('Error uploading scan history ${history.id}: $e');
          }
        }
        if (syncedIds.isNotEmpty) {
          await _localDb.markScanHistoriesAsSynced(syncedIds);
        }
        return syncedIds.length;
      }
    } catch (e) {
      Logger.error('Error in pushPendingScanHistories: $e');
      return 0;
    }
  }

  /// Periksa dan sinkronkan otomatis saat startup jika database lokal masih kosong
  Future<void> checkAndInitialSync() async {
    try {
      final localCount = await _localDb.getStudentCount();
      if (localCount == 0) {
        Logger.info('Local database is empty. Running initial sync...');
        await pullStudentsFromFirebase();
      }
    } catch (e) {
      Logger.error('Initial sync check error: $e');
    }
  }

  Future<DateTime?> getLastSyncTime() async {
    try {
      final val = await _localDb.getMetadata('last_sync_timestamp');
      if (val != null) {
        return DateTime.tryParse(val);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<int> getTotalLocalStudents() async {
    return await _localDb.getStudentCount();
  }

  Future<int> getUnsyncedScanCount() async {
    final list = await _localDb.getUnsyncedScanHistories();
    return list.length;
  }
}
