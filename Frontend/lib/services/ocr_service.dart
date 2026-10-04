import 'dart:io';
import 'dart:convert';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import '../models/student.dart';
import '../utils/logging/logger.dart';
import 'student_service.dart';
import 'performance_tracker.dart';

class OCRService {
  static final TextRecognizer _textRecognizer = TextRecognizer();
  static final ImagePicker _imagePicker = ImagePicker();

  /// Ambil gambar dari kamera untuk OCR
  static Future<File?> captureImageFromCamera() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        preferredCameraDevice: CameraDevice.rear,
      );

      if (image != null) {
        return File(image.path);
      }
      return null;
    } catch (e) {
      Logger.error('Error capturing image from camera: $e');
      return null;
    }
  }

  /// Ambil gambar dari galeri untuk OCR
  static Future<File?> pickImageFromGallery() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (image != null) {
        return File(image.path);
      }
      return null;
    } catch (e) {
      Logger.error('Error picking image from gallery: $e');
      return null;
    }
  }

  /// Ekstrak teks dari gambar menggunakan OCR
  static Future<String> extractTextFromImage(
    File imageFile, {
    BenchmarkSession? session,
  }) async {
    try {
      final InputImage inputImage = InputImage.fromFile(imageFile);
      session?.markImageLoaded();

      session?.markOCRProcessStart();
      final RecognizedText recognizedText = await _textRecognizer.processImage(
        inputImage,
      );
      session?.markOCRProcessEnd();

      return recognizedText.text;
    } catch (e) {
      session?.recordError(stage: 'OCR Recognition', error: e.toString());
      Logger.error('Error extracting text from image: $e');
      throw Exception('Gagal mengekstrak teks dari gambar: $e');
    }
  }

  /// Ekstrak informasi mahasiswa dari teks OCR dengan algoritma yang lebih akurat
  static OCRResult extractStudentInfoFromText(String text) {
    final lines = text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    String? nim;
    String? name;
    String? faculty;
    String? studyProgram;
    String? vehicleNumber;

    // Pattern untuk mendeteksi NIM (tepat 10 digit angka)
    final nimPattern = RegExp(r'\b\d{10}\b');

    // Pattern untuk mendeteksi nomor plat kendaraan
    final platePattern = RegExp(r'\b[A-Z]{1,2}\s*\d{1,4}\s*[A-Z]{1,3}\b');

    // Pattern untuk nama lengkap (lebih fleksibel)
    final namePattern = RegExp(r'^[A-Za-z\s\.\,\-]+$');

    // Keywords untuk fakultas (lebih komprehensif)
    final facultyKeywords = [
      'fakultas',
      'fak',
      'faculty',
      'keguruan',
      'ekonomi',
      'psikologi',
      'sains',
      'teknologi',
      'farmasi',
      'hukum',
      'sastra',
      'budaya',
      'komunikasi',
      'agama',
      'islam',
      'kesehatan',
      'masyarakat',
      'kedokteran',
      'pertanian',
      'peternakan',
      'perikanan',
      'kehutanan',
      'ilmu',
      'sosial',
      'politik',
      'adab',
      'dakwah',
      'syariah',
      'tarbiyah',
      'ushuluddin',
    ];

    // Keywords untuk program studi berdasarkan data fakultas UAD
    final prodiKeywords = [
      'program studi',
      'prodi',
      'jurusan',
      'program',
      // Program studi dari FacultyData
      'bimbingan',
      'konseling',
      'pendidikan',
      'bahasa',
      'sastra',
      'indonesia',
      'inggris',
      'biologi',
      'fisika',
      'guru',
      'paud',
      'sekolah',
      'dasar',
      'matematika',
      'pancasila',
      'kewarganegaraan',
      'vokasional',
      'teknik',
      'elektronika',
      'otomotif',
      'manajemen',
      'akuntansi',
      'ekonomi',
      'pembangunan',
      'bisnis',
      'makanan',
      'psikologi',
      'sistem',
      'informasi',
      'informatika',
      'industri',
      'kimia',
      'elektro',
      'teknologi',
      'pangan',
      'farmasi',
      'hukum',
      'komunikasi',
      'arab',
      'hadis',
      'agama',
      'islam',
      'perbankan',
      'syariah', 'kesehatan', 'masyarakat', 'gizi', 'kedokteran',
    ];

    // Kata kunci yang harus dihindari untuk nama
    final excludeWords = [
      'universitas',
      'institut',
      'sekolah',
      'tinggi',
      'kartu',
      'mahasiswa',
      'student',
      'card',
      'ktm',
      'identity',
      'id',
      'nomor',
      'number',
      'fakultas',
      'program',
      'jurusan',
      'prodi',
      'nim',
      'semester',
      'tahun',
      'angkatan',
      'kelas',
      'tempat',
      'tanggal',
      'lahir',
      'alamat',
      'jenis',
      'kelamin',
      'agama',
      'status',
      'berlaku',
      'sampai',
      'dengan',
    ];

    // Set untuk menyimpan indeks baris yang sudah diidentifikasi sebagai fakultas
    Set<int> facultyLineIndices = {};

    // Ukur durasi ekstraksi NIM dengan Stopwatch
    final Stopwatch nimStopwatch = Stopwatch()..start();

    // Ekstrak NIM terlebih dahulu (prioritas utama)
    for (final line in lines) {
      if (nim == null) {
        final nimMatch = nimPattern.firstMatch(line);
        if (nimMatch != null) {
          nim = nimMatch.group(0);
          break; // Ambil NIM pertama yang ditemukan
        }
      }
    }
    nimStopwatch.stop();
    final int nimDuration = nimStopwatch.elapsedMilliseconds;

    // FASE 1: Identifikasi fakultas terlebih dahulu dengan prioritas tinggi untuk "Fakultas ..."
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].toLowerCase();
      final originalLine = lines[i];

      if (faculty == null) {
        // Pattern untuk mendeteksi baris yang diawali dengan "Fakultas" (case-insensitive)
        final facultyPattern = RegExp(
          r'^fakultas\s+(.+)',
          caseSensitive: false,
        );
        final facultyMatch = facultyPattern.firstMatch(line);

        if (facultyMatch != null) {
          // Ambil seluruh baris asli yang mengandung "Fakultas ..."
          faculty = originalLine;
          facultyLineIndices.add(i);
          break; // Prioritas tertinggi, langsung break
        } else if (line.trim().toLowerCase() == 'fakultas') {
          // Jika hanya kata "Fakultas" saja, cek baris berikutnya
          if (i + 1 < lines.length) {
            final nextLine = lines[i + 1];
            final nextLineLower = nextLine.toLowerCase();

            // Pastikan baris berikutnya bukan NIM, nama, atau kata kunci lain
            if (!nimPattern.hasMatch(nextLine) &&
                !platePattern.hasMatch(nextLine.toUpperCase()) &&
                nextLine.length > 3 &&
                nextLine.length < 80 &&
                !excludeWords.any((word) => nextLineLower.contains(word))) {
              // Gabungkan "Fakultas" dengan baris berikutnya
              faculty = 'Fakultas $nextLine';
              facultyLineIndices.add(i); // Baris "Fakultas"
              facultyLineIndices.add(i + 1); // Baris nama fakultas
              break;
            }
          }
        }
      }
    }

    // FASE 2: Jika belum menemukan fakultas dengan pattern "Fakultas ...", cari dengan fallback
    if (faculty == null) {
      for (int i = 0; i < lines.length; i++) {
        final line = lines[i].toLowerCase();
        final originalLine = lines[i];

        // Fallback: cek apakah baris mengandung kata kunci fakultas
        bool containsFacultyKeyword = facultyKeywords.any(
          (keyword) => line.contains(keyword),
        );

        if (containsFacultyKeyword) {
          faculty = originalLine;
          facultyLineIndices.add(i);
          break;
        } else {
          // Cek baris yang mungkin fakultas berdasarkan pola umum
          if (originalLine.length > 10 && originalLine.length < 80) {
            // Cek apakah mengandung kata-kata yang umum di nama fakultas
            final facultyIndicators = [
              'fakultas',
              'fak',
              'ilmu',
              'ekonomi',
              'hukum',
              'kedokteran',
              'pertanian',
              'sastra',
              'sosial',
              'agama',
              'keguruan',
              'pendidikan',
            ];
            if (facultyIndicators.any(
              (indicator) => line.contains(indicator),
            )) {
              faculty = originalLine;
              facultyLineIndices.add(i);
              break;
            }
          }
        }
      }
    }

    // FASE 3: Ekstrak informasi lainnya dengan menghindari baris fakultas
    int nameDurationAccumulated = 0;
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].toLowerCase();
      final originalLine = lines[i];

      // Skip baris yang sudah diidentifikasi sebagai fakultas
      if (facultyLineIndices.contains(i)) {
        continue;
      }

      // Cari nomor plat kendaraan
      if (vehicleNumber == null) {
        final plateMatch = platePattern.firstMatch(originalLine.toUpperCase());
        if (plateMatch != null) {
          vehicleNumber = plateMatch.group(0)?.replaceAll(RegExp(r'\s+'), ' ');
        }
      }

      // Cari program studi (hanya jika bukan baris fakultas)
      if (studyProgram == null) {
        // Cek apakah baris mengandung kata kunci program studi
        bool containsProdiKeyword = prodiKeywords.any(
          (keyword) => line.contains(keyword),
        );

        if (containsProdiKeyword) {
          studyProgram = originalLine;
        } else {
          // Cek baris setelah fakultas yang mungkin program studi
          if (faculty != null) {
            // Cari baris yang mungkin program studi setelah fakultas ditemukan
            for (int facultyIndex in facultyLineIndices) {
              if (i > facultyIndex && i <= facultyIndex + 3) {
                // Baris ini berada 1-3 baris setelah fakultas
                if (originalLine.length > 3 &&
                    originalLine.length < 60 &&
                    !nimPattern.hasMatch(originalLine) &&
                    !platePattern.hasMatch(originalLine.toUpperCase()) &&
                    !excludeWords.any((word) => line.contains(word))) {
                  // Cek apakah baris ini mengandung kata-kata yang umum untuk program studi
                  final prodiIndicators = [
                    'teknik',
                    'kimia',
                    'industri',
                    'elektro',
                    'informatika',
                    'komputer',
                    'manajemen',
                    'akuntansi',
                    'ekonomi',
                    'hukum',
                    'farmasi',
                    'kedokteran',
                    'psikologi',
                    'biologi',
                    'fisika',
                    'matematika',
                    'bahasa',
                    'sastra',
                    'komunikasi',
                    'pendidikan',
                    'guru',
                    'paud',
                    'dasar',
                    'inggris',
                    'indonesia',
                    'arab',
                    'konseling',
                    'bimbingan',
                    'pancasila',
                    'agama',
                    'islam',
                    'kesehatan',
                    'masyarakat',
                    'gizi',
                    'sistem',
                    'informasi',
                    'teknologi',
                    'pangan',
                    'vokasional',
                    'otomotif',
                    'elektronika',
                  ];

                  if (prodiIndicators.any(
                    (indicator) => line.contains(indicator),
                  )) {
                    studyProgram = originalLine;
                    break;
                  }
                }
              }
            }
          }

          // Jika masih belum ditemukan, cek dengan logika lama
          if (studyProgram == null && faculty != null && i > 0) {
            final prevLine = lines[i - 1].toLowerCase();
            if (facultyKeywords.any((keyword) => prevLine.contains(keyword))) {
              if (originalLine.length > 5 &&
                  originalLine.length < 60 &&
                  !nimPattern.hasMatch(originalLine) &&
                  !platePattern.hasMatch(originalLine.toUpperCase())) {
                studyProgram = originalLine;
              }
            }
          }
        }
      }

      // Cari nama lengkap dengan algoritma yang lebih cerdas
      if (name == null && originalLine.length > 3 && originalLine.length < 60) {
        final Stopwatch nameStopwatch = Stopwatch()..start();
        // Pastikan baris hanya mengandung huruf, spasi, dan karakter nama yang valid
        if (namePattern.hasMatch(originalLine)) {
          final lowerLine = originalLine.toLowerCase();

          // Pastikan tidak mengandung angka (kecuali di akhir untuk gelar)
          bool hasNumbers = RegExp(r'\d').hasMatch(originalLine);

          // Pastikan tidak mengandung kata kunci yang harus dihindari
          bool hasExcludeWords = excludeWords.any(
            (word) => lowerLine.contains(word),
          );

          // Pastikan bukan NIM atau nomor plat
          bool isNimOrPlate =
              nimPattern.hasMatch(originalLine) ||
              platePattern.hasMatch(originalLine.toUpperCase());
          bool likelyName = false;
          if (nim != null) {
            for (int j = 0; j < lines.length; j++) {
              if (lines[j].contains(nim)) {
                if (i > j && i <= j + 3) {
                  likelyName = true;
                  break;
                }
              }
            }
          } else if (i < 5) {
            likelyName = true;
          }

          final words = originalLine
              .split(' ')
              .where((w) => w.isNotEmpty)
              .toList();
          bool hasMultipleWords = words.length >= 2;
          bool looksLikeName = words.every(
            (word) =>
                word.isNotEmpty &&
                word[0].toUpperCase() == word[0] &&
                RegExp(r'^[A-Za-z\.\-]+$').hasMatch(word),
          );

          if (!hasNumbers &&
              !hasExcludeWords &&
              !isNimOrPlate &&
              hasMultipleWords &&
              looksLikeName &&
              likelyName) {
            name = originalLine;
          }
        }
        nameStopwatch.stop();
        if (name != null) {
          nameDurationAccumulated += nameStopwatch.elapsedMilliseconds;
        }
      }
    }

    // Post-processing
    if (name != null) {
      name = name.replaceAll(RegExp(r'^[^\w]+|[^\w]+$'), '').trim();
      if (name.length < 3 || name.length > 50) {
        name = null;
      }
    }

    if (faculty != null) {
      faculty = faculty.replaceAll(RegExp(r'^[^\w\s]+|[^\w\s]+$'), '').trim();
      if (faculty.length < 5) {
        faculty = null;
      }
    }

    if (studyProgram != null) {
      // Bersihkan program studi dari karakter yang tidak perlu
      studyProgram = studyProgram
          .replaceAll(RegExp(r'^[^\w\s]+|[^\w\s]+$'), '')
          .trim();
      if (studyProgram.length < 3) {
        studyProgram = null;
      }
    }

    return OCRResult(
      extractedText: text,
      nim: nim,
      name: name,
      faculty: faculty,
      studyProgram: studyProgram,
      vehicleNumber: vehicleNumber,
      nimExtractionTimeMs: nimDuration,
      nameExtractionTimeMs: nameDurationAccumulated,
    );
  }

  /// Proses gambar dan cari data mahasiswa dengan format JSON response
  static Future<OCRProcessResult> processImageAndFindStudent(
    File imageFile, {
    BenchmarkSession? session,
  }) async {
    try {
      // Ekstrak teks dari gambar
      final extractedText =
          await extractTextFromImage(imageFile, session: session);

      if (extractedText.isEmpty) {
        await session?.recordError(
          stage: 'OCR Recognition',
          error: 'Tidak ada teks yang terdeteksi dalam gambar',
        );
        return OCRProcessResult(
          success: false,
          message: 'Tidak ada teks yang terdeteksi dalam gambar',
          extractedText: extractedText,
        );
      }

      // Ekstrak informasi mahasiswa dari teks
      final ocrResult = extractStudentInfoFromText(extractedText);
      session?.setOCRExtractionResults(
        ocrNim: ocrResult.nim,
        ocrName: ocrResult.name,
        nimDurationMs: ocrResult.nimExtractionTimeMs,
        nameDurationMs: ocrResult.nameExtractionTimeMs,
      );

      // Validasi NIM harus ada dan tepat 10 digit
      if (ocrResult.nim == null || ocrResult.nim!.length != 10) {
        await session?.recordError(
          stage: 'NIM Validation',
          error: 'NIM tidak terdeteksi atau tidak valid (harus 10 digit)',
        );
        return OCRProcessResult(
          success: false,
          message: 'NIM tidak terdeteksi atau tidak valid (harus 10 digit)',
          ocrResult: ocrResult,
          extractedText: extractedText,
          jsonResponse: _createOCROnlyResponse(ocrResult, 'NIM tidak valid'),
        );
      }

      Student? student;

      // Cek apakah NIM tersebut ada di database
      session?.markFirebaseQueryStart();
      student = await StudentService.getStudentByNIM(ocrResult.nim!);
      session?.markFirebaseQueryEnd(isFound: student != null);

      if (student != null) {
        session?.startVerification();
        final bool hasVehicle = student.vehicleNumber.isNotEmpty;
        final String verificationStatus =
            hasVehicle ? 'valid' : 'incomplete_vehicle';
        session?.completeVerification(
          hasStudent: true,
          hasVehicle: hasVehicle,
          dbNim: student.nim,
          dbName: student.name,
          status: verificationStatus,
        );

        // NIM cocok dengan database - kembalikan data mahasiswa sesuai database
        await StudentService.saveScanHistory(student, scanMethod: 'ocr');

        return OCRProcessResult(
          success: true,
          message: 'Data mahasiswa ditemukan di database',
          student: student,
          ocrResult: ocrResult,
          extractedText: extractedText,
          jsonResponse: _createDatabaseResponse(student),
        );
      } else {
        session?.completeVerification(
          hasStudent: false,
          hasVehicle: false,
          dbNim: null,
          dbName: null,
          status: 'not_found',
        );

        // NIM tidak ditemukan di database - tampilkan hasil ekstraksi OCR dengan status "belum ada"
        return OCRProcessResult(
          success: false,
          message: 'NIM tidak ditemukan di database',
          ocrResult: ocrResult,
          extractedText: extractedText,
          jsonResponse: _createOCROnlyResponse(ocrResult, 'belum ada'),
        );
      }
    } catch (e) {
      await session?.recordError(
        stage: 'Process Image',
        error: e.toString(),
      );
      Logger.error('Error processing image: $e');
      return OCRProcessResult(
        success: false,
        message: 'Terjadi kesalahan saat memproses gambar: $e',
        extractedText: '',
        jsonResponse: _createErrorResponse(e.toString()),
      );
    }
  }

  /// Membuat response JSON untuk data dari database
  static Map<String, dynamic> _createDatabaseResponse(Student student) {
    return {
      'status': 'found',
      'source': 'database',
      'data': {
        'nim': student.nim,
        'nama_lengkap': student.name,
        'fakultas': student.faculty,
        'program_studi': student.studyProgram,
        'nomor_kendaraan': student.vehicleNumber,
        'jenis_kendaraan': student.vehicleType,
        'waktu_scan': student.scanTime.toIso8601String(),
      },
    };
  }

  /// Membuat response JSON untuk data dari OCR saja
  static Map<String, dynamic> _createOCROnlyResponse(
    OCRResult ocrResult,
    String status,
  ) {
    return {
      'status': status,
      'source': 'ocr',
      'data': {
        'nim': ocrResult.nim,
        'nama_lengkap': ocrResult.name,
        'fakultas': ocrResult.faculty,
        'program_studi': ocrResult.studyProgram,
        'nomor_kendaraan': ocrResult.vehicleNumber,
      },
    };
  }

  /// Membuat response JSON untuk error
  static Map<String, dynamic> _createErrorResponse(String error) {
    return {
      'status': 'error',
      'source': 'system',
      'message': error,
      'data': null,
    };
  }

  /// Dispose text recognizer
  static void dispose() {
    _textRecognizer.close();
  }
}

/// Model untuk hasil OCR
class OCRResult {
  final String extractedText;
  final String? nim;
  final String? name;
  final String? faculty;
  final String? studyProgram;
  final String? vehicleNumber;
  final int nimExtractionTimeMs;
  final int nameExtractionTimeMs;

  OCRResult({
    required this.extractedText,
    this.nim,
    this.name,
    this.faculty,
    this.studyProgram,
    this.vehicleNumber,
    this.nimExtractionTimeMs = 0,
    this.nameExtractionTimeMs = 0,
  });

  /// Konversi ke JSON untuk response
  Map<String, dynamic> toJson() {
    return {
      'nim': nim,
      'nama_lengkap': name,
      'fakultas': faculty,
      'program_studi': studyProgram,
      'nomor_kendaraan': vehicleNumber,
    };
  }

  @override
  String toString() {
    return 'OCRResult(nim: $nim, name: $name, faculty: $faculty, studyProgram: $studyProgram, vehicleNumber: $vehicleNumber)';
  }
}

/// Model untuk hasil proses OCR lengkap
class OCRProcessResult {
  final bool success;
  final String message;
  final Student? student;
  final OCRResult? ocrResult;
  final String extractedText;
  final Map<String, dynamic>? jsonResponse;

  OCRProcessResult({
    required this.success,
    required this.message,
    this.student,
    this.ocrResult,
    required this.extractedText,
    this.jsonResponse,
  });

  /// Mendapatkan response dalam format JSON string
  String getJsonString() {
    if (jsonResponse != null) {
      return jsonEncode(jsonResponse);
    }
    return '{}';
  }
}
