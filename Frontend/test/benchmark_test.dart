import 'package:flutter_test/flutter_test.dart';
import 'package:stnk_check_uad/services/performance_tracker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PerformanceTracker & BenchmarkSession Tests', () {
    test('QR BenchmarkSession records timings and formats CSV correctly',
        () async {
      final session = await BenchmarkSession.startQR('QR-001');

      expect(session.method, 'QR');
      expect(session.runId, 'QR-001');

      // Simulate QR detected
      session.markQRDetected();
      expect(session.scanOrOcrTimeMs >= 0, isTrue);

      // Simulate Identity parsed
      session.markIdentityParsed('2000018001');
      expect(session.nimResult, '2000018001');

      // Simulate Firebase Query
      session.markFirebaseQueryStart();
      session.markFirebaseQueryEnd(isFound: true);
      expect(session.studentFound, isTrue);

      // Simulate Verification
      session.startVerification();
      session.completeVerification(
        hasStudent: true,
        hasVehicle: true,
        dbNim: '2000018001',
        dbName: 'AHMAD DAHLAN',
        status: 'valid',
      );

      expect(session.vehicleFound, isTrue);
      expect(session.verificationStatus, 'valid');
      expect(session.nimMatch, isTrue);

      // Simulate Result Displayed
      await session.markResultDisplayed();
      expect(session.resultDisplayed, isTrue);
      expect(session.isCompleted, isTrue);

      // Verify CSV row format
      final csvRow = session.toCsvRow();
      expect(csvRow.contains('QR-001'), isTrue);
      expect(csvRow.contains(',QR,'), isTrue);
      expect(csvRow.contains(',valid,'), isTrue);
      expect(csvRow.contains('"2000018001"'), isTrue);
    });

    test('OCR BenchmarkSession records timings and comparisons correctly',
        () async {
      final session = await BenchmarkSession.startOCR('OCR-001');

      expect(session.method, 'OCR');
      expect(session.runId, 'OCR-001');

      // Simulate Image Loaded
      session.markImageLoaded();

      // Simulate ML Kit Process
      session.markOCRProcessStart();
      session.markOCRProcessEnd();

      // Simulate Regex Extraction
      session.setOCRExtractionResults(
        ocrNim: '2000018001',
        ocrName: 'AHMAD DAHLAN',
        nimDurationMs: 2,
        nameDurationMs: 4,
      );

      expect(session.nimResult, '2000018001');
      expect(session.nameResult, 'AHMAD DAHLAN');
      expect(session.nimExtractTimeMs, 2);
      expect(session.nameExtractTimeMs, 4);

      // Simulate Firebase Query
      session.markFirebaseQueryStart();
      session.markFirebaseQueryEnd(isFound: true);

      // Simulate Verification
      session.startVerification();
      session.completeVerification(
        hasStudent: true,
        hasVehicle: true,
        dbNim: '2000018001',
        dbName: 'AHMAD DAHLAN',
        status: 'valid',
      );

      expect(session.nimMatch, isTrue);
      expect(session.nameMatch, isTrue);

      await session.markResultDisplayed();
      expect(session.resultDisplayed, isTrue);

      final csvRow = session.toCsvRow();
      expect(csvRow.contains('OCR-001'), isTrue);
      expect(csvRow.contains(',OCR,'), isTrue);
      expect(csvRow.contains('true,true,valid,true'), isTrue);
    });

    test('BenchmarkSession error recording works correctly', () async {
      final session = await BenchmarkSession.startQR('QR-999');
      session.markFirebaseQueryStart();
      session.markFirebaseQueryEnd(isFound: false);

      await session.recordError(
        stage: 'Firebase Query',
        error: 'Student not found',
      );

      expect(session.verificationStatus, 'error');
      expect(session.errorMessage.contains('Student not found'), isTrue);
      expect(session.isCompleted, isTrue);
    });
  });
}
