import 'package:flutter/material.dart';
import '../../utils/ui/dialog_helper.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../models/student.dart';
import '../../services/student_service.dart';
import '../../services/api_service.dart';
import '../../config/platform_config.dart';
import 'result_screen.dart';
import 'widgets/manual_input_dialog.dart';
import '../student/add_edit_student_screen.dart';
import '../../services/performance_tracker.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> with WidgetsBindingObserver {
  late MobileScannerController cameraController;
  bool isScanning = false;
  bool isNavigating = false;
  bool isCameraInitialized = false;
  BenchmarkSession? _currentQrSession;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  void _initializeCamera() {
    cameraController = MobileScannerController(
      torchEnabled: false,
      detectionSpeed: DetectionSpeed.noDuplicates,
    );
  }

  Future<void> _retryCamera() async {
    if (!mounted) return;
    setState(() {
      isCameraInitialized = false;
    });
    try {
      await cameraController.stop();
    } catch (_) {}
    try {
      await cameraController.start();
    } catch (e) {
      // ignore: avoid_print
      print('Retry camera error: $e');
    }
  }

  Future<void> _startQrSession() async {
    _currentQrSession = await BenchmarkSession.startQR();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    cameraController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!isCameraInitialized) return;

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _pauseCamera();
        break;
      case AppLifecycleState.resumed:
        if (!isNavigating && !cameraController.isStarting) {
          _resumeCamera();
        }
        break;
      case AppLifecycleState.inactive:
        break;
    }
  }

  void _pauseCamera() {
    try {
      if (isCameraInitialized) {
        cameraController.stop();
      }
    } catch (e) {
      // ignore: avoid_print
      print('Error pausing camera: $e');
    }
  }

  void _resumeCamera() {
    try {
      if (mounted &&
          !isNavigating &&
          isCameraInitialized &&
          !cameraController.isStarting) {
        cameraController.start();
        _startQrSession();
      }
    } catch (e) {
      // ignore: avoid_print
      print('Error resuming camera: $e');
    }
  }

  void _onDetect(BarcodeCapture capture) async {
    if (isScanning || isNavigating) return;

    setState(() {
      isScanning = true;
      isNavigating = true;
    });

    // Pause camera immediately to prevent multiple scans
    _pauseCamera();

    final session = _currentQrSession ?? await BenchmarkSession.startQR();
    session.markQRDetected();

    final List<Barcode> barcodes = capture.barcodes;
    String? rawValue;

    for (final barcode in barcodes) {
      if (barcode.rawValue != null) {
        rawValue = barcode.rawValue!;
        break;
      }
    }

    if (rawValue != null) {
      session.markIdentityParsed(rawValue);
      _processBarcode(rawValue, session);
    } else {
      await session.recordError(
        stage: 'QR Detection',
        error: 'Barcode rawValue is null',
      );
      _resetScanningState();
    }
  }

  Future<void> _processBarcode(
    String barcodeData,
    BenchmarkSession session,
  ) async {
    try {
      session.markFirebaseQueryStart();
      // Try by barcode then by NIM
      Student? student = await StudentService.getStudentByBarcode(barcodeData);
      student ??= await StudentService.getStudentByNIM(barcodeData);
      session.markFirebaseQueryEnd(isFound: student != null);

      if (student != null) {
        session.startVerification();
        final bool hasVehicle = student.vehicleNumber.isNotEmpty;
        final String verificationStatus =
            hasVehicle ? 'valid' : 'incomplete_vehicle';
        session.completeVerification(
          hasStudent: true,
          hasVehicle: hasVehicle,
          dbNim: student.nim,
          dbName: student.name,
          status: verificationStatus,
        );

        await StudentService.saveScanHistory(student, scanMethod: 'barcode');

        if (mounted) {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => ResultScreen(
                student: student!,
                onResultRendered: () {
                  session.markResultDisplayed();
                },
              ),
            ),
          );
          _resetScanningState();
        }
      } else {
        session.completeVerification(
          hasStudent: false,
          hasVehicle: false,
          dbNim: null,
          dbName: null,
          status: 'not_found',
        );

        final isAdmin = await ApiService.isCurrentUserAdmin();
        if (mounted) {
          await session.recordError(
            stage: 'Firebase Query',
            error:
                'Data mahasiswa tidak ditemukan untuk barcode/NIM: $barcodeData',
            updateDisplayed: true,
          );
          if (!mounted) return;

          if (isAdmin) {
            await _promptAddData(
              title: 'Data tidak ditemukan',
              message:
                  'Barcode/NIM yang di-scan tidak terdaftar dalam sistem.\nApakah Anda ingin menambahkan datanya?',
              initialBarcode: barcodeData,
              scanMethod: 'barcode',
            );
          } else {
            DialogHelper.showErrorDialog(
              context,
              'Data tidak ditemukan',
              'Barcode/NIM yang di-scan tidak terdaftar dalam sistem. Hubungi administrator untuk menambahkan data.',
            );
          }
        }
        _resetScanningState();
      }
    } catch (e) {
      await session.recordError(
        stage: 'Process Barcode',
        error: e.toString(),
      );
      if (mounted) {
        DialogHelper.showErrorDialog(context, 'Error', 'Terjadi kesalahan: $e');
      }
      _resetScanningState();
    }
  }

  void _resetScanningState() {
    setState(() {
      isScanning = false;
      isNavigating = false;
    });

    // Resume camera after a short delay to prevent immediate re-scanning
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted && !isNavigating && isCameraInitialized) {
        _resumeCamera();
      }
    });
  }

  Future<void> _promptAddData({
    required String title,
    required String message,
    String? initialBarcode,
    String? scanMethod,
  }) async {
    final action = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.person_search,
                  color: Colors.orange,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: Text(message, style: const TextStyle(fontSize: 14)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop('cancel'),
              child: const Text('Batal'),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop('add'),
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Tambah Data'),
            ),
          ],
        );
      },
    );

    if (action == 'add' && mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => AddEditStudentScreen(
            initialBarcode: initialBarcode,
            scanMethod: scanMethod,
          ),
        ),
      );
    }
  }

  void _showManualInputDialog() {
    // Pause camera when showing manual input dialog
    if (isCameraInitialized) {
      _pauseCamera();
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return ManualInputDialog(
          onSubmit: (inputValue, inputType) {
            _processManualInput(inputValue, inputType);
          },
        );
      },
    ).then((_) {
      if (isCameraInitialized && !isNavigating) {
        _resumeCamera();
      }
    });
  }

  Future<void> _processManualInput(String inputValue, String inputType) async {
    setState(() {
      isScanning = true;
      isNavigating = true;
    });

    try {
      Student? student;

      if (inputType == 'NIM') {
        student = await StudentService.getStudentByNIM(inputValue);
      } else {
        student = await StudentService.getStudentByVehicleNumber(inputValue);
      }

      if (student != null) {
        await StudentService.saveScanHistory(student, scanMethod: 'manual');

        if (mounted) {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => ResultScreen(student: student!),
            ),
          );
          _resetScanningState();
        }
      } else {
        final isAdmin = await ApiService.isCurrentUserAdmin();
        if (mounted) {
          if (isAdmin) {
            await _promptAddData(
              title: 'Data tidak ditemukan',
              message:
                  '${inputType == 'NIM' ? 'NIM' : 'Nomor plat'} yang diinput tidak terdaftar dalam sistem.\nApakah Anda ingin menambahkan datanya?',
              initialBarcode: inputType == 'NIM' ? inputValue : null,
              scanMethod: 'manual',
            );
          } else {
            DialogHelper.showErrorDialog(
              context,
              'Data tidak ditemukan',
              '${inputType == 'NIM' ? 'NIM' : 'Nomor plat'} yang diinput tidak terdaftar dalam sistem. Hubungi administrator.',
            );
          }
        }
        _resetScanningState();
      }
    } catch (e) {
      if (mounted) {
        DialogHelper.showErrorDialog(context, 'Error', 'Terjadi kesalahan: $e');
      }
      _resetScanningState();
    }
  }

  // Widget untuk platform yang tidak didukung clean design
  Widget _buildUnsupportedPlatformWidget() {
    return Container(
      color: Colors.grey[50],
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Icon(
                  Icons.qr_code_scanner_rounded,
                  size: 48,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Scanner Tidak Tersedia',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                PlatformConfig.unsupportedPlatformMessage,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () {
                  _showDemoDataDialog();
                },
                icon: const Icon(Icons.info_outline, size: 20),
                label: const Text('Lihat Data Demo'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shadowColor: Colors.black26,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Dialog untuk menampilkan data demo
  void _showDemoDataDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.info_outline,
                  color: Colors.blue,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Data Demo Tersedia',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          content: const Text(
            'Untuk testing, Anda dapat menggunakan fitur "Input Manual" dengan data berikut:\n\n'
            'NIM: 2021001, 2021002, 2021003, 2021004, 2021005\n'
            'Plat: AB 1234 CD, AB 5678 EF, AB 9012 GH, AB 3456 IJ, AB 7890 KL',
            style: TextStyle(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(foregroundColor: Colors.grey[600]),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Show platform warning if needed
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    PlatformConfig.showPlatformWarning();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Column(
        children: [
          // Modern Gradient Header dengan Glassmorphism & Responsive Layout
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF1565C0),
                  Color(0xFF1976D2),
                  Color(0xFF1E88E5),
                ],
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1565C0).withOpacity(0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Row 1: Icon + Title "QR Scanner" + Action Badges (Flash & Status)
                    Row(
                      children: [
                        // Icon Scanner
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.35),
                              width: 1.5,
                            ),
                          ),
                          child: const Icon(
                            Icons.qr_code_scanner_rounded,
                            size: 24,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Title
                        const Expanded(
                          child: Text(
                            'QR Scanner',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),

                        // Actions: Flash Button & Status Badge
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isCameraInitialized) ...[
                              ValueListenableBuilder<TorchState>(
                                valueListenable: cameraController.torchState,
                                builder: (context, state, _) {
                                  final isFlashOn = state == TorchState.on;
                                  return Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: _toggleFlash,
                                      borderRadius: BorderRadius.circular(12),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isFlashOn
                                              ? Colors.amber.withOpacity(0.35)
                                              : Colors.white.withOpacity(0.2),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                            color: isFlashOn
                                                ? Colors.amber
                                                : Colors.white.withOpacity(0.4),
                                            width: 1.5,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              isFlashOn
                                                  ? Icons.flash_on_rounded
                                                  : Icons.flash_off_rounded,
                                              size: 16,
                                              color: isFlashOn
                                                  ? Colors.amber
                                                  : Colors.white,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Flash',
                                              style: TextStyle(
                                                color: isFlashOn
                                                    ? Colors.amber
                                                    : Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(width: 8),
                            ],

                            // Status badge
                            if (isScanning)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.35),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.orange.withOpacity(0.6),
                                    width: 1.5,
                                  ),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                          Colors.white,
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 6),
                                    Text(
                                      'Scanning',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else if (isCameraInitialized)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.4),
                                    width: 1.5,
                                  ),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.check_circle_rounded,
                                      size: 15,
                                      color: Colors.white,
                                    ),
                                    SizedBox(width: 5),
                                    Text(
                                      'Ready',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Row 2: Subtitle / Instruction Pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isScanning
                                ? Icons.sync_rounded
                                : !isCameraInitialized
                                    ? Icons.hourglass_top_rounded
                                    : Icons.center_focus_strong_rounded,
                            size: 15,
                            color: Colors.white.withOpacity(0.9),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              isScanning
                                  ? 'Memproses data scan KTM...'
                                  : !isCameraInitialized
                                      ? 'Memuat kamera...'
                                      : 'Arahkan kamera ke barcode / QR KTM',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.95),
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.2,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Content area
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  const SizedBox(height: 24),

                  // Scanner area dengan frame modern
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        // Scanner frame dengan corner indicators
                        Container(
                          height: MediaQuery.of(context).size.height * 0.48,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Colors.white, Colors.grey.shade50],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFF1565C0,
                                ).withOpacity(0.15),
                                blurRadius: 24,
                                offset: const Offset(0, 8),
                                spreadRadius: 0,
                              ),
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: Stack(
                              children: [
                                // Scanner content
                                if (PlatformConfig.enableScanner)
                                  MobileScanner(
                                    controller: cameraController,
                                    onScannerStarted: (arguments) {
                                      if (mounted) {
                                        setState(() {
                                          isCameraInitialized = true;
                                        });
                                        _startQrSession();
                                      }
                                    },
                                    errorBuilder: (context, error, child) {
                                      return _buildCameraErrorWidget(error);
                                    },
                                    placeholderBuilder: (context, child) {
                                      return _buildCameraLoadingWidget();
                                    },
                                    fit: BoxFit.cover,
                                    onDetect: _onDetect,
                                  )
                                else
                                  _buildUnsupportedPlatformWidget(),

                                // Corner indicators (frame)
                                if (!isScanning) ...[
                                  // Top left
                                  Positioned(
                                    top: 20,
                                    left: 20,
                                    child: Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        border: Border(
                                          top: BorderSide(
                                            color: const Color(0xFF1565C0),
                                            width: 4,
                                          ),
                                          left: BorderSide(
                                            color: const Color(0xFF1565C0),
                                            width: 4,
                                          ),
                                        ),
                                        borderRadius: const BorderRadius.only(
                                          topLeft: Radius.circular(12),
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Top right
                                  Positioned(
                                    top: 20,
                                    right: 20,
                                    child: Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        border: Border(
                                          top: BorderSide(
                                            color: const Color(0xFF1565C0),
                                            width: 4,
                                          ),
                                          right: BorderSide(
                                            color: const Color(0xFF1565C0),
                                            width: 4,
                                          ),
                                        ),
                                        borderRadius: const BorderRadius.only(
                                          topRight: Radius.circular(12),
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Bottom left
                                  Positioned(
                                    bottom: 20,
                                    left: 20,
                                    child: Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        border: Border(
                                          bottom: BorderSide(
                                            color: const Color(0xFF1565C0),
                                            width: 4,
                                          ),
                                          left: BorderSide(
                                            color: const Color(0xFF1565C0),
                                            width: 4,
                                          ),
                                        ),
                                        borderRadius: const BorderRadius.only(
                                          bottomLeft: Radius.circular(12),
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Bottom right
                                  Positioned(
                                    bottom: 20,
                                    right: 20,
                                    child: Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        border: Border(
                                          bottom: BorderSide(
                                            color: const Color(0xFF1565C0),
                                            width: 4,
                                          ),
                                          right: BorderSide(
                                            color: const Color(0xFF1565C0),
                                            width: 4,
                                          ),
                                        ),
                                        borderRadius: const BorderRadius.only(
                                          bottomRight: Radius.circular(12),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],

                                // Floating Flash Toggle Button
                                if (!isScanning && isCameraInitialized)
                                  Positioned(
                                    bottom: 20,
                                    left: 0,
                                    right: 0,
                                    child: Center(
                                      child: _buildFlashToggleButton(),
                                    ),
                                  ),

                                // Processing overlay dengan blur
                                if (isScanning)
                                  Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Colors.black.withOpacity(0.3),
                                          Colors.black.withOpacity(0.5),
                                        ],
                                      ),
                                    ),
                                    child: Center(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 32,
                                          vertical: 24,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.95),
                                          borderRadius: BorderRadius.circular(
                                            24,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(
                                                0.2,
                                              ),
                                              blurRadius: 20,
                                              spreadRadius: 5,
                                            ),
                                          ],
                                        ),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(16),
                                              decoration: BoxDecoration(
                                                color: const Color(
                                                  0xFF1565C0,
                                                ).withOpacity(0.1),
                                                shape: BoxShape.circle,
                                              ),
                                              child:
                                                  const CircularProgressIndicator(
                                                    color: Color(0xFF1565C0),
                                                    strokeWidth: 3,
                                                  ),
                                            ),
                                            const SizedBox(height: 16),
                                            const Text(
                                              'Memproses Data',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFF212121),
                                                letterSpacing: 0.3,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Mohon tunggu sebentar...',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w500,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Action button dengan gradient
                        Container(
                          width: double.infinity,
                          height: 58,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            gradient: const LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [Color(0xFF1565C0), Color(0xFF1976D2)],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF1565C0).withOpacity(0.4),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                                spreadRadius: 0,
                              ),
                            ],
                          ),
                          child: ElevatedButton.icon(
                            onPressed: isScanning
                                ? null
                                : _showManualInputDialog,
                            icon: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.keyboard_rounded,
                                size: 20,
                              ),
                            ),
                            label: const Text(
                              'Input Manual NIM / Plat',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                                letterSpacing: 0.5,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Info card dengan icon modern
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            const Color(0xFF1565C0).withOpacity(0.08),
                            const Color(0xFF1976D2).withOpacity(0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFF1565C0).withOpacity(0.2),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1565C0).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.lightbulb_rounded,
                              color: Color(0xFF1565C0),
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Tips Scanning:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                    color: Color(0xFF1565C0),
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '• Arahkan kamera ke barcode dengan jelas\n'
                                  '• Pastikan tidak ada pantulan cahaya\n'
                                  '• Jarak ideal: 10-15 cm dari barcode',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[700],
                                    height: 1.6,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Widget for camera loading state
  Widget _buildCameraLoadingWidget() {
    return Container(
      color: Colors.grey[50],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: CircularProgressIndicator(
                color: Theme.of(context).colorScheme.primary,
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Memuat Kamera...',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Mohon tunggu sebentar',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraErrorWidget(MobileScannerException error) {
    String message = 'Terjadi kesalahan pada kamera.';
    switch (error.errorCode) {
      case MobileScannerErrorCode.permissionDenied:
        message =
            'Izin kamera ditolak. Harap berikan izin akses kamera di pengaturan perangkat.';
        break;
      case MobileScannerErrorCode.unsupported:
        message = 'Perangkat ini tidak mendukung pemindaian kamera.';
        break;
      case MobileScannerErrorCode.controllerUninitialized:
        message = 'Kamera belum siap.';
        break;
      default:
        message = error.errorDetails?.message?.isNotEmpty == true
            ? error.errorDetails!.message!
            : 'Gagal mengaktifkan kamera. Silakan coba lagi.';
        break;
    }

    return Container(
      color: Colors.grey[900],
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.videocam_off_rounded,
                size: 36,
                color: Colors.redAccent,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Kamera Tidak Terbuka',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 13,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _retryCamera,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Coba Lagi'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleFlash() async {
    try {
      if (isCameraInitialized) {
        await cameraController.toggleTorch();
      }
    } catch (e) {
      // ignore: avoid_print
      print('Error toggling flash: $e');
    }
  }

  Widget _buildFlashToggleButton() {
    return ValueListenableBuilder<TorchState>(
      valueListenable: cameraController.torchState,
      builder: (context, state, _) {
        final isFlashOn = state == TorchState.on;
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _toggleFlash,
            borderRadius: BorderRadius.circular(24),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isFlashOn
                    ? Colors.amber.shade500
                    : Colors.black.withOpacity(0.55),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isFlashOn ? Colors.amber.shade200 : Colors.white54,
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isFlashOn
                        ? Colors.amber.withOpacity(0.4)
                        : Colors.black26,
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isFlashOn
                        ? Icons.flash_on_rounded
                        : Icons.flash_off_rounded,
                    color: isFlashOn ? Colors.black87 : Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isFlashOn ? 'Flash ON' : 'Flash OFF',
                    style: TextStyle(
                      color: isFlashOn ? Colors.black87 : Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
