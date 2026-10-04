import 'dart:io';
import 'package:flutter/material.dart';
import '../../utils/ui/dialog_helper.dart';
import 'package:flutter/services.dart';
import '../../services/ocr_service.dart';
import '../../services/api_service.dart';
import 'result_screen.dart';
import '../student/add_edit_student_screen.dart';
import '../../services/performance_tracker.dart';

class OCRScreen extends StatefulWidget {
  const OCRScreen({super.key});

  @override
  State<OCRScreen> createState() => _OCRScreenState();
}

class _OCRScreenState extends State<OCRScreen> {
  File? _selectedImage;
  bool _isProcessing = false;
  String? _extractedText;
  OCRResult? _ocrResult;

  Future<void> _captureFromCamera() async {
    setState(() {
      _isProcessing = true;
    });

    try {
      final imageFile = await OCRService.captureImageFromCamera();
      if (imageFile != null) {
        setState(() {
          _selectedImage = imageFile;
        });
        await _processImage(imageFile);
      }
    } catch (e) {
      DialogHelper.showErrorDialog(
        context,
        'Error',
        'Gagal mengambil gambar dari kamera: $e',
      );
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _pickFromGallery() async {
    setState(() {
      _isProcessing = true;
    });

    try {
      final imageFile = await OCRService.pickImageFromGallery();
      if (imageFile != null) {
        setState(() {
          _selectedImage = imageFile;
        });
        await _processImage(imageFile);
      }
    } catch (e) {
      DialogHelper.showErrorDialog(
        context,
        'Error',
        'Gagal mengambil gambar dari galeri: $e',
      );
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _processImage(File imageFile) async {
    setState(() {
      _isProcessing = true;
    });

    final session = await BenchmarkSession.startOCR();

    try {
      final result = await OCRService.processImageAndFindStudent(
        imageFile,
        session: session,
      );
      final isAdmin = await ApiService.isCurrentUserAdmin();

      setState(() {
        _extractedText = result.extractedText;
        _ocrResult = result.ocrResult;
      });

      if (result.success && result.student != null) {
        // Navigasi ke halaman hasil jika data mahasiswa ditemukan
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ResultScreen(
              student: result.student!,
              onResultRendered: () {
                session.markResultDisplayed();
              },
            ),
          ),
        );
      } else {
        // Tandai error/not found pada session saat data mahasiswa tidak ditemukan
        final errorMsg = result.message.isNotEmpty
            ? result.message
            : 'Data mahasiswa tidak ditemukan di database';
        await session.recordError(
          stage: 'Firebase Query',
          error: errorMsg,
          updateDisplayed: true,
        );
        if (!mounted) return;

        // Check if we should show "add data" prompt instead of detailed OCR dialog
        if (result.ocrResult != null && result.ocrResult!.nim != null) {
          if (isAdmin) {
            _promptAddDataFromOCR(result);
          } else {
            DialogHelper.showErrorDialog(
              context,
              'Data tidak ditemukan',
              'Data KTM ini belum terdaftar. Hubungi administrator.',
            );
          }
        } else {
          // Tampilkan dialog dengan hasil OCR
          DialogHelper.showErrorDialog(
            context,
            'Data tidak ditemukan',
            'Data KTM ini belum terdaftar. Hubungi administrator.',
          );
        }
      }
    } catch (e) {
      await session.recordError(
        stage: 'Process Image',
        error: e.toString(),
      );
      DialogHelper.showErrorDialog(
        context,
        'Error',
        'Gagal memproses gambar: $e',
      );
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _promptAddDataFromOCR(OCRProcessResult result) async {
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
              const Expanded(
                child: Text(
                  'Data tidak ditemukan',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Data mahasiswa dengan NIM ${result.ocrResult!.nim} tidak ditemukan dalam sistem.',
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              if (result.ocrResult != null) ...[
                const Text(
                  'Data yang berhasil diekstrak dari KTM:',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue[100]!),
                  ),
                  child: Column(
                    children: [
                      if (result.ocrResult!.nim != null)
                        _buildInfoRow('NIM', result.ocrResult!.nim!),
                      if (result.ocrResult!.name != null)
                        _buildInfoRow('Nama Lengkap', result.ocrResult!.name!),
                      _buildInfoRow(
                        'Fakultas',
                        result.ocrResult!.faculty ?? 'fakultas',
                      ),
                      if (result.ocrResult!.studyProgram != null)
                        _buildInfoRow(
                          'Program Studi',
                          result.ocrResult!.studyProgram!,
                        ),
                      if (result.ocrResult!.vehicleNumber != null)
                        _buildInfoRow(
                          'Nomor Kendaraan',
                          result.ocrResult!.vehicleNumber!,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      color: Colors.green[600],
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Data akan diisi otomatis dari hasil OCR. Anda hanya perlu melengkapi nomor plat kendaraan.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.green[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Apakah Anda ingin menambahkan data mahasiswa ini ke sistem?',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ],
          ),
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
            initialBarcode: result.ocrResult!.nim,
            scanMethod: 'ocr',
            ocrResult: result.ocrResult, // Kirim data OCR lengkap
          ),
        ),
      );
    }
  }

  void _showOCRResultDialog(OCRProcessResult result) {
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
                  color: (result.success ? Colors.green : Colors.orange)
                      .withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  result.success ? Icons.check_circle : Icons.info_outline,
                  color: result.success ? Colors.green : Colors.orange,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  result.success ? 'Data Ditemukan' : 'Hasil OCR',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(result.message, style: const TextStyle(fontSize: 14)),
                  const SizedBox(height: 16),

                  // Tampilkan response JSON
                  if (result.jsonResponse != null) ...[
                    const Text(
                      'Response JSON:',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: SelectableText(
                        result.getJsonString(),
                        style: const TextStyle(
                          fontSize: 11,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Tampilkan informasi yang terdeteksi dalam format yang mudah dibaca
                  if (result.ocrResult != null) ...[
                    const Text(
                      'Data yang diekstrak:',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue[100]!),
                      ),
                      child: Column(
                        children: [
                          if (result.ocrResult!.nim != null)
                            _buildInfoRow('NIM', result.ocrResult!.nim!),
                          if (result.ocrResult!.name != null)
                            _buildInfoRow(
                              'Nama Lengkap',
                              result.ocrResult!.name!,
                            ),
                          _buildInfoRow(
                            'Fakultas',
                            result.ocrResult!.faculty ?? 'fakultas',
                          ),
                          if (result.ocrResult!.studyProgram != null)
                            _buildInfoRow(
                              'Program Studi',
                              result.ocrResult!.studyProgram!,
                            ),
                          if (result.ocrResult!.vehicleNumber != null)
                            _buildInfoRow(
                              'Nomor Kendaraan',
                              result.ocrResult!.vehicleNumber!,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Tampilkan status database
                  if (result.jsonResponse != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: result.success
                            ? Colors.green[50]
                            : Colors.orange[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: result.success
                              ? Colors.green[200]!
                              : Colors.orange[200]!,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            result.success ? Icons.check_circle : Icons.info,
                            color: result.success
                                ? Colors.green[600]
                                : Colors.orange[600],
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              result.success
                                  ? 'Status: Data ditemukan di database'
                                  : 'Status: ${result.jsonResponse!['status']}',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: result.success
                                    ? Colors.green[700]
                                    : Colors.orange[700],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Tampilkan teks mentah yang terdeteksi
                  if (result.extractedText.isNotEmpty) ...[
                    ExpansionTile(
                      title: const Text(
                        'Teks mentah yang terdeteksi',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      tilePadding: EdgeInsets.zero,
                      childrenPadding: const EdgeInsets.only(top: 8),
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: SelectableText(
                            result.extractedText,
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            if (result.jsonResponse != null)
              TextButton.icon(
                onPressed: () async {
                  // Copy JSON to clipboard
                  await Clipboard.setData(
                    ClipboardData(text: result.getJsonString()),
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: Colors.white,
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Text('JSON berhasil disalin ke clipboard'),
                          ],
                        ),
                        backgroundColor: Colors.green[600],
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('Copy JSON'),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.primary,
                ),
              ),
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

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }

  void _clearImage() {
    setState(() {
      _selectedImage = null;
      _extractedText = null;
      _ocrResult = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          // Compact Modern Header (matching student list design)
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.primary.withOpacity(0.8),
                ],
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Row(
                  children: [
                    // Icon with modern design
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: const Icon(
                        Icons.text_fields_rounded,
                        size: 24,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Title and subtitle
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width * 0.6,
                            ),
                            child: Text(
                              'Pemindaian KTM',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                          const SizedBox(height: 2),
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width * 0.6,
                            ),
                            child: Text(
                              'Pindai KTM untuk verifikasi data',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 12,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Status indicator
                    if (_isProcessing)
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        ),
                      )
                    else if (_selectedImage != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_circle,
                              size: 14,
                              color: Colors.white,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Siap',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
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
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  // Image preview area with modern design
                  Container(
                    margin: const EdgeInsets.all(20),
                    height: MediaQuery.of(context).size.height * 0.45,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _isProcessing
                            ? Colors.orange[300]!
                            : _selectedImage != null
                            ? Theme.of(
                                context,
                              ).colorScheme.primary.withOpacity(0.3)
                            : Colors.grey[200]!,
                        width: 2,
                      ),
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 15,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Stack(
                        children: [
                          if (_selectedImage != null)
                            Image.file(
                              _selectedImage!,
                              width: double.infinity,
                              height: double.infinity,
                              fit: BoxFit.contain,
                            )
                          else
                            _buildPlaceholderWidget(),

                          // Processing overlay
                          if (_isProcessing)
                            Container(
                              color: Colors.black.withOpacity(0.4),
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.9),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Column(
                                        children: [
                                          CircularProgressIndicator(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                            strokeWidth: 3,
                                          ),
                                          const SizedBox(height: 12),
                                          const Text(
                                            'Memproses gambar...',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                          // Clear button
                          if (_selectedImage != null && !_isProcessing)
                            Positioned(
                              top: 12,
                              right: 12,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.red[500],
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.red.withOpacity(0.3),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: IconButton(
                                  onPressed: _clearImage,
                                  icon: const Icon(
                                    Icons.clear,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                  constraints: const BoxConstraints(
                                    minWidth: 36,
                                    minHeight: 36,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // Modern Action buttons
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Column(
                      children: [
                        // Camera button
                        Container(
                          width: double.infinity,
                          height: 52,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Theme.of(
                                  context,
                                ).colorScheme.primary.withOpacity(0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ElevatedButton.icon(
                            onPressed: _isProcessing
                                ? null
                                : _captureFromCamera,
                            icon: const Icon(Icons.camera_alt, size: 20),
                            label: const Text(
                              'Ambil Foto',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.primary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Gallery button
                        Container(
                          width: double.infinity,
                          height: 52,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: OutlinedButton.icon(
                            onPressed: _isProcessing ? null : _pickFromGallery,
                            icon: const Icon(Icons.photo_library, size: 20),
                            label: const Text(
                              'Pilih dari Galeri',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Theme.of(
                                context,
                              ).colorScheme.primary,
                              backgroundColor: Colors.white,
                              side: BorderSide(
                                color: Theme.of(
                                  context,
                                ).colorScheme.primary.withOpacity(0.3),
                                width: 1.5,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderWidget() {
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
                  Icons.text_fields_rounded,
                  size: 48,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Belum Ada Gambar',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Ambil foto KTM atau pilih dari galeri untuk memulai ekstraksi teks',
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
      ),
    );
  }
}
