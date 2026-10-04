import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

/// Service untuk melacak, mencatat durasi (Stopwatch), mencetak log debug performa,
/// dan mengekspor hasil benchmark ke file CSV untuk kebutuhan pengujian skripsi Bab 4.
class PerformanceTracker {
  static int _inMemoryQRCounter = 0;
  static int _inMemoryOCRCounter = 0;

  /// Mendapatkan Run ID berikutnya untuk QR (contoh: QR-001)
  static Future<String> getNextQRRunId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      int count = (prefs.getInt('benchmark_qr_counter') ?? 0) + 1;
      await prefs.setInt('benchmark_qr_counter', count);
      return 'QR-${count.toString().padLeft(3, '0')}';
    } catch (_) {
      _inMemoryQRCounter++;
      return 'QR-${_inMemoryQRCounter.toString().padLeft(3, '0')}';
    }
  }

  /// Mendapatkan Run ID berikutnya untuk OCR (contoh: OCR-001)
  static Future<String> getNextOCRRunId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      int count = (prefs.getInt('benchmark_ocr_counter') ?? 0) + 1;
      await prefs.setInt('benchmark_ocr_counter', count);
      return 'OCR-${count.toString().padLeft(3, '0')}';
    } catch (_) {
      _inMemoryOCRCounter++;
      return 'OCR-${_inMemoryOCRCounter.toString().padLeft(3, '0')}';
    }
  }

  /// Reset counter run ID jika diperlukan
  static Future<void> resetRunCounters() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('benchmark_qr_counter');
      await prefs.remove('benchmark_ocr_counter');
    } catch (_) {}
    _inMemoryQRCounter = 0;
    _inMemoryOCRCounter = 0;
  }

  /// Header CSV untuk pengujian performa skripsi
  static String get csvHeader =>
      'run_id,timestamp,method,image_load_time_ms,scan_or_ocr_time_ms,identity_parse_time_ms,nim_extract_time_ms,name_extract_time_ms,firebase_query_time_ms,verification_time_ms,total_time_ms,nim_expected,nim_result,nim_match,name_expected,name_result,name_match,student_found,vehicle_found,verification_status,result_displayed,error_message';

  /// Mengirim metrik benchmark ke server Backend Express & Supabase
  static Future<void> appendToCsv(BenchmarkSession session) async {
    try {
      debugPrint('[BENCHMARK] Mengirim metrik sesi ${session.runId} ke Backend...');
      // Kirim ke backend Express secara asynchronous non-blocking
      unawaited(ApiService.sendBenchmarkMetrics(session.toJson()));
    } catch (e) {
      debugPrint('[BENCHMARK ERROR] Gagal mengirim ke backend: $e');
    }
  }
}

/// Sesi pengukuran performa untuk satu kali proses scan (QR atau OCR)
class BenchmarkSession {
  final String method; // 'QR' atau 'OCR'
  String runId;
  final DateTime startTime;

  // Stopwatches untuk pengukuran akurat
  final Stopwatch _totalStopwatch = Stopwatch();
  final Stopwatch _stageStopwatch = Stopwatch();
  final Stopwatch _queryStopwatch = Stopwatch();
  final Stopwatch _verificationStopwatch = Stopwatch();

  // Durasi (milidetik)
  int imageLoadTimeMs = 0;
  int scanOrOcrTimeMs = 0; // QR Scan Time atau OCR Processing Time
  int identityParseTimeMs = 0; // Identity Parse Time (QR)
  int nimExtractTimeMs = 0; // Regex extraction (OCR)
  int nameExtractTimeMs = 0; // Regex extraction (OCR)
  int firebaseQueryTimeMs = 0;
  int verificationTimeMs = 0;
  int totalTimeMs = 0;

  // Data Hasil
  String nimExpected = '-';
  String nimResult = '-';
  bool nimMatch = false;

  String nameExpected = '-';
  String nameResult = '-';
  bool nameMatch = false;

  bool studentFound = false;
  bool vehicleFound = false;
  String verificationStatus = 'unknown'; // 'valid', 'invalid', 'not_found', etc.
  bool resultDisplayed = false;

  String errorMessage = '';
  bool isCompleted = false;

  BenchmarkSession._({
    required this.method,
    required this.runId,
  }) : startTime = DateTime.now() {
    _totalStopwatch.start();
    _stageStopwatch.start();
  }

  /// Inisialisasi sesi QR Code
  static Future<BenchmarkSession> startQR([String? runId]) async {
    final id = runId ?? await PerformanceTracker.getNextQRRunId();
    final session = BenchmarkSession._(method: 'QR', runId: id);
    return session;
  }

  /// Inisialisasi sesi OCR
  static Future<BenchmarkSession> startOCR([String? runId]) async {
    final id = runId ?? await PerformanceTracker.getNextOCRRunId();
    final session = BenchmarkSession._(method: 'OCR', runId: id);
    return session;
  }

  // ─────────────────────────────────────────────────────────────────
  // Tahapan QR Code
  // ─────────────────────────────────────────────────────────────────

  /// 2. QR_DETECTED - Ketika QR Code berhasil terbaca oleh scanner
  void markQRDetected() {
    scanOrOcrTimeMs = _stageStopwatch.elapsedMilliseconds;
    _stageStopwatch.reset();
    _stageStopwatch.start();
  }

  /// 3. IDENTITY_PARSED - Ketika identitas/NIM dari QR berhasil diperoleh
  void markIdentityParsed(String parsedData) {
    identityParseTimeMs = _stageStopwatch.elapsedMilliseconds;
    _stageStopwatch.stop();
    nimResult = parsedData;
  }

  // ─────────────────────────────────────────────────────────────────
  // Tahapan OCR
  // ─────────────────────────────────────────────────────────────────

  /// 2. IMAGE_LOADED - Ketika citra berhasil dimuat & disiapkan ke InputImage
  void markImageLoaded() {
    imageLoadTimeMs = _stageStopwatch.elapsedMilliseconds;
    _stageStopwatch.reset();
    _stageStopwatch.start();
  }

  /// 3. OCR_PROCESS_START - Dimulainya proses TextRecognizer ML Kit
  void markOCRProcessStart() {
    _stageStopwatch.reset();
    _stageStopwatch.start();
  }

  /// 4. OCR_PROCESS_END - Selesainya proses TextRecognizer ML Kit
  void markOCRProcessEnd() {
    scanOrOcrTimeMs = _stageStopwatch.elapsedMilliseconds;
    _stageStopwatch.stop();
  }

  /// 5 & 6. NIM_EXTRACTED & NAME_EXTRACTED - Waktu ekstraksi regex teks
  void setOCRExtractionResults({
    required String? ocrNim,
    required String? ocrName,
    int? nimDurationMs,
    int? nameDurationMs,
  }) {
    nimResult = ocrNim ?? '-';
    nameResult = ocrName ?? '-';
    if (nimDurationMs != null) nimExtractTimeMs = nimDurationMs;
    if (nameDurationMs != null) nameExtractTimeMs = nameDurationMs;
  }

  // ─────────────────────────────────────────────────────────────────
  // Tahapan Firebase & Verifikasi (Umum untuk QR & OCR)
  // ─────────────────────────────────────────────────────────────────

  /// 4/7. FIREBASE_QUERY_START - Sebelum request query ke Firebase
  void markFirebaseQueryStart() {
    _queryStopwatch.reset();
    _queryStopwatch.start();
  }

  /// 5/8. FIREBASE_QUERY_END - Setelah response Firebase diterima
  void markFirebaseQueryEnd({required bool isFound}) {
    _queryStopwatch.stop();
    firebaseQueryTimeMs = _queryStopwatch.elapsedMilliseconds;
    studentFound = isFound;
  }

  /// 7-8/10-11. VEHICLE_DATA_LOADED & VERIFICATION_COMPLETE
  void startVerification() {
    _verificationStopwatch.reset();
    _verificationStopwatch.start();
  }

  void completeVerification({
    required bool hasStudent,
    required bool hasVehicle,
    String? dbNim,
    String? dbName,
    String? status,
  }) {
    _verificationStopwatch.stop();
    verificationTimeMs = _verificationStopwatch.elapsedMilliseconds;

    studentFound = hasStudent;
    vehicleFound = hasVehicle;

    if (dbNim != null && dbNim.isNotEmpty) {
      nimExpected = dbNim;
      if (nimResult != '-') {
        nimMatch = (nimExpected.trim() == nimResult.trim());
      }
    }

    if (dbName != null && dbName.isNotEmpty) {
      nameExpected = dbName;
      if (nameResult != '-') {
        // Cek kecocokan nama (case-insensitive)
        final nExp = nameExpected.trim().toLowerCase();
        final nRes = nameResult.trim().toLowerCase();
        nameMatch = (nExp == nRes || nExp.contains(nRes) || nRes.contains(nExp));
      }
    }

    if (status != null) {
      verificationStatus = status;
    } else {
      if (studentFound && vehicleFound) {
        verificationStatus = 'valid';
      } else if (studentFound && !vehicleFound) {
        verificationStatus = 'incomplete_vehicle';
      } else {
        verificationStatus = 'not_found';
      }
    }
  }

  /// 9/12. RESULT_DISPLAYED - Ketika hasil scanning selesai dirender pada layar
  Future<void> markResultDisplayed() async {
    if (isCompleted) return;
    _totalStopwatch.stop();
    totalTimeMs = _totalStopwatch.elapsedMilliseconds;
    resultDisplayed = true;
    isCompleted = true;

    // Log ke konsol sesuai format Bab 4
    _printPerformanceLog();

    // Simpan ke CSV
    await PerformanceTracker.appendToCsv(this);
  }

  /// Catat jika terjadi error pada salah satu tahapan
  Future<void> recordError({
    required String stage,
    required String error,
    bool updateDisplayed = true,
  }) async {
    if (isCompleted) return;
    _totalStopwatch.stop();
    totalTimeMs = _totalStopwatch.elapsedMilliseconds;
    errorMessage = '[$stage] $error';
    verificationStatus = 'error';
    resultDisplayed = updateDisplayed;
    isCompleted = true;

    _printErrorLog(stage, error);
    await PerformanceTracker.appendToCsv(this);
  }

  // ─────────────────────────────────────────────────────────────────
  // Cetak Log Konsol
  // ─────────────────────────────────────────────────────────────────

  void _printPerformanceLog() {
    final buffer = StringBuffer();
    buffer.writeln('\n========== TEST RUN ==========');
    buffer.writeln('Run ID                : $runId');
    buffer.writeln('Timestamp             : ${startTime.toIso8601String()}');
    buffer.writeln('Method                : $method\n');

    if (method == 'QR') {
      buffer.writeln('QR Scan Time          : $scanOrOcrTimeMs ms');
      buffer.writeln('Identity Parse Time   : $identityParseTimeMs ms');
      buffer.writeln('Firebase Query Time   : $firebaseQueryTimeMs ms');
      buffer.writeln('Verification Time     : $verificationTimeMs ms\n');
      buffer.writeln('TOTAL TIME            : $totalTimeMs ms\n');
      buffer.writeln('Student Found         : $studentFound');
      buffer.writeln('Vehicle Found         : $vehicleFound');
      buffer.writeln('Verification Status   : $verificationStatus');
      buffer.writeln('Result Displayed      : $resultDisplayed');
    } else {
      // OCR
      buffer.writeln('Image Load Time       : $imageLoadTimeMs ms');
      buffer.writeln('OCR Processing Time   : $scanOrOcrTimeMs ms');
      if (nimExtractTimeMs > 0 || nameExtractTimeMs > 0) {
        buffer.writeln('NIM Extract Time      : $nimExtractTimeMs ms');
        buffer.writeln('Name Extract Time     : $nameExtractTimeMs ms');
      }
      buffer.writeln('Firebase Query Time   : $firebaseQueryTimeMs ms');
      buffer.writeln('Verification Time     : $verificationTimeMs ms\n');
      buffer.writeln('TOTAL TIME            : $totalTimeMs ms\n');
      buffer.writeln('NIM Expected          : $nimExpected');
      buffer.writeln('NIM OCR               : $nimResult');
      buffer.writeln('NIM Match             : $nimMatch\n');
      buffer.writeln('Name Expected         : $nameExpected');
      buffer.writeln('Name OCR              : $nameResult');
      buffer.writeln('Name Match            : $nameMatch\n');
      buffer.writeln('Student Found         : $studentFound');
      buffer.writeln('Vehicle Found         : $vehicleFound');
      buffer.writeln('Verification Status   : $verificationStatus');
      buffer.writeln('Result Displayed      : $resultDisplayed');
    }

    buffer.writeln('==============================');
    debugPrint(buffer.toString());
  }

  void _printErrorLog(String stage, String error) {
    final buffer = StringBuffer();
    buffer.writeln('\n========== TEST RUN (ERROR) ==========');
    buffer.writeln('Run ID        : $runId');
    buffer.writeln('Method        : $method');
    buffer.writeln('Stage         : $stage');
    buffer.writeln('Error         : $error');
    buffer.writeln('Duration      : $totalTimeMs ms');
    buffer.writeln('======================================');
    debugPrint(buffer.toString());
  }

  /// Konversi data sesi ke satu baris CSV
  String toCsvRow() {
    return [
      runId,
      startTime.toIso8601String(),
      method,
      imageLoadTimeMs,
      scanOrOcrTimeMs,
      identityParseTimeMs,
      nimExtractTimeMs,
      nameExtractTimeMs,
      firebaseQueryTimeMs,
      verificationTimeMs,
      totalTimeMs,
      '"$nimExpected"',
      '"$nimResult"',
      nimMatch,
      '"$nameExpected"',
      '"$nameResult"',
      nameMatch,
      studentFound,
      vehicleFound,
      verificationStatus,
      resultDisplayed,
      '"$errorMessage"',
    ].join(',');
  }

  /// Konversi data sesi ke Map JSON untuk dikirim ke Backend
  Map<String, dynamic> toJson() {
    return {
      'run_id': runId,
      'timestamp': startTime.toIso8601String(),
      'method': method,
      'image_load_time_ms': imageLoadTimeMs,
      'scan_or_ocr_time_ms': scanOrOcrTimeMs,
      'identity_parse_time_ms': identityParseTimeMs,
      'nim_extract_time_ms': nimExtractTimeMs,
      'name_extract_time_ms': nameExtractTimeMs,
      'query_time_ms': firebaseQueryTimeMs,
      'verification_time_ms': verificationTimeMs,
      'total_time_ms': totalTimeMs,
      'nim_expected': nimExpected,
      'nim_result': nimResult,
      'nim_match': nimMatch,
      'name_expected': nameExpected,
      'name_result': nameResult,
      'name_match': nameMatch,
      'student_found': studentFound,
      'vehicle_found': vehicleFound,
      'verification_status': verificationStatus,
      'result_displayed': resultDisplayed,
      'error_message': errorMessage,
    };
  }
}
