import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import '../models/student.dart';
import '../models/scan_history.dart';
import '../utils/logging/logger.dart';
import 'local_database_service.dart';

const String _dbBaseUrl =
    'https://scan-ktm-default-rtdb.asia-southeast1.firebasedatabase.app';

class FirebaseService {
  // Cache untuk student data (5 menit)
  static final Map<String, Student?> _studentCache = {};
  static final Map<String, DateTime> _cacheTimestamp = {};
  static const Duration _cacheDuration = Duration(minutes: 5);
  static const Duration _httpTimeout = Duration(seconds: 25);

  // Auth token cache (50 menit)
  static String? _cachedAuthToken;
  static DateTime? _tokenCachedAt;

  // Check if cache is still valid
  static bool _isCacheValid(String key) {
    if (!_cacheTimestamp.containsKey(key)) return false;
    final age = DateTime.now().difference(_cacheTimestamp[key]!);
    return age < _cacheDuration;
  }

  // Helper untuk membangun URI beserta auth token dan query parameters
  static Future<Uri> _buildUri(String path,
      [Map<String, String>? queryParams]) async {
    final uri = Uri.parse('$_dbBaseUrl/$path.json');
    final Map<String, String> params = Map.from(uri.queryParameters);
    if (queryParams != null) {
      params.addAll(queryParams);
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final now = DateTime.now();
        if (_cachedAuthToken != null &&
            _tokenCachedAt != null &&
            now.difference(_tokenCachedAt!) < const Duration(minutes: 50)) {
          params['auth'] = _cachedAuthToken!;
        } else {
          final token =
              await user.getIdToken().timeout(const Duration(seconds: 6));
          if (token != null) {
            _cachedAuthToken = token;
            _tokenCachedAt = now;
            params['auth'] = token;
          }
        }
      } catch (_) {
        if (_cachedAuthToken != null) {
          params['auth'] = _cachedAuthToken!;
        }
      }
    }
    return uri.replace(queryParameters: params.isEmpty ? null : params);
  }

  // ─── REST API Helper ──────────────────────────────────────────────

  static Future<dynamic> _restGet(String path,
      [Map<String, String>? queryParams]) async {
    try {
      final uri = await _buildUri(path, queryParams);
      final response = await http.get(uri).timeout(_httpTimeout);

      if (response.statusCode == 200) {
        if (response.body == 'null' || response.body.isEmpty) return null;
        return json.decode(response.body);
      } else {
        Logger.error('REST GET failed: HTTP ${response.statusCode}');
        return null;
      }
    } catch (e) {
      Logger.error('REST GET $path error: $e');
      return null;
    }
  }

  static Future<bool> _restPost(String path, Map<String, dynamic> data) async {
    try {
      final uri = await _buildUri(path);
      final response = await http
          .post(uri, body: json.encode(data))
          .timeout(_httpTimeout);
      return response.statusCode == 200;
    } catch (e) {
      Logger.error('REST POST $path error: $e');
      return false;
    }
  }

  static Future<bool> _restPut(String path, Map<String, dynamic> data) async {
    try {
      final uri = await _buildUri(path);
      final response = await http
          .put(uri, body: json.encode(data))
          .timeout(_httpTimeout);
      return response.statusCode == 200;
    } catch (e) {
      Logger.error('REST PUT $path error: $e');
      return false;
    }
  }

  static Future<bool> _restPatch(String path, Map<String, dynamic> data) async {
    try {
      final uri = await _buildUri(path);
      final response = await http
          .patch(uri, body: json.encode(data))
          .timeout(_httpTimeout);
      return response.statusCode == 200;
    } catch (e) {
      Logger.error('REST PATCH $path error: $e');
      return false;
    }
  }

  static Future<bool> _restDelete(String path) async {
    try {
      final uri = await _buildUri(path);
      final response = await http.delete(uri).timeout(_httpTimeout);
      return response.statusCode == 200;
    } catch (e) {
      Logger.error('REST DELETE $path error: $e');
      return false;
    }
  }

  static Future<bool> saveUserProfile(
      String uid, Map<String, dynamic> data) async {
    try {
      return await _restPut('users/$uid', data);
    } catch (e) {
      Logger.error('Error saving user profile: $e');
      return false;
    }
  }

  // ─── Role Authorization Methods ──────────────────────────────────────────

  static Future<String> getCurrentUserRole() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return 'user';
      final data = await _restGet('users/${user.uid}/role');
      if (data != null) return data.toString().replaceAll('"', '').trim();
      return 'user';
    } catch (e) {
      Logger.error('Error getting user role: $e');
      return 'user';
    }
  }

  static Future<bool> isCurrentUserAdmin() async {
    // Bypass khusus untuk skripsi: Semua user dianggap admin agar tombol tambah muncul
    return true;
  }

  // Method untuk reset database connection
  static void resetDatabaseConnection() {
    Logger.info('Firebase Database connection reset (REST Mode)');
  }

  static Future<bool> testConnection() async {
    try {
      await _restPut(
          'test', {'timestamp': DateTime.now().millisecondsSinceEpoch});
      await _restDelete('test');
      return true;
    } catch (e) {
      return false;
    }
  }

  // ─── Data Access Methods ───────────────────────────────────────────────

  static Future<Student?> getStudentByNIM(String nim) async {
    try {
      if (_isCacheValid(nim) && _studentCache.containsKey(nim)) {
        return _studentCache[nim];
      }

      final data = await _restGet('students/$nim');
      if (data != null && data is Map) {
        final studentMap = Map<dynamic, dynamic>.from(data);
        studentMap['nim'] ??= nim;
        final student = Student.fromFirestore(studentMap);

        _studentCache[nim] = student;
        _cacheTimestamp[nim] = DateTime.now();
        return student;
      }
      return null;
    } catch (e) {
      Logger.error('Error getting student by NIM: $e');
      return null;
    }
  }

  static Future<Student?> getStudentByVehicleNumber(
      String vehicleNumber) async {
    try {
      // RTDB requires quotes around string values in query params
      dynamic data = await _restGet('students', {
        'orderBy': '"vehicle_number"',
        'equalTo': '"$vehicleNumber"'
      });

      if (data == null || (data is Map && data.isEmpty)) {
        data = await _restGet('students', {
          'orderBy': '"vehicleNumber"',
          'equalTo': '"$vehicleNumber"'
        });
      }

      if (data != null && data is Map && data.isNotEmpty) {
        final key = data.keys.first;
        final studentData = Map<dynamic, dynamic>.from(data[key]);
        studentData['nim'] ??= key.toString();
        return Student.fromFirestore(studentData);
      }
      return null;
    } catch (e) {
      Logger.error('Error getting student by vehicle number: $e');
      return null;
    }
  }

  static Future<bool> saveScanHistory(Student student, String location,
      {String scanMethod = 'unknown'}) async {
    try {
      final scanData = {
        'student_nim': student.nim,
        'student_name': student.name,
        'faculty': student.faculty,
        'study_program': student.studyProgram,
        'vehicle_number': student.vehicleNumber,
        'vehicle_type': student.vehicleType,
        'scan_time': DateTime.now().millisecondsSinceEpoch,
        'scan_method': scanMethod,
        'location': location,
      };
      return await _restPost('scan_history', scanData);
    } catch (e) {
      Logger.error('Error saving scan history: $e');
      return false;
    }
  }

  static Future<List<ScanHistory>> getAllScanHistory(
      {int limit = 100}) async {
    try {
      final data = await _restGet('scan_history', {
        'orderBy': '"\$key"',
        'limitToLast': '$limit'
      });

      if (data != null && data is Map) {
        final historyList = <ScanHistory>[];
        data.forEach((key, value) {
          if (value is Map) {
            historyList.add(ScanHistory.fromFirestore(
                Map<dynamic, dynamic>.from(value), key.toString()));
          }
        });
        historyList.sort((a, b) => b.scanTime.compareTo(a.scanTime));
        return historyList;
      }
      return [];
    } catch (e) {
      Logger.error('Error getting scan history: $e');
      return [];
    }
  }

  static Future<List<Student>> getScanHistoryAsStudents() async {
    try {
      final historyList = await getAllScanHistory();
      return historyList.map((history) => history.toStudent()).toList();
    } catch (e) {
      Logger.error('Error getting scan history as students: $e');
      return [];
    }
  }

  static Future<List<Student>> getAllStudents({int limit = 100}) async {
    try {
      final data = await _restGet(
          'students', {'orderBy': '"\$key"', 'limitToFirst': '$limit'});

      if (data != null && data is Map) {
        final list = <Student>[];
        data.forEach((key, value) {
          if (value is Map) {
            final studentMap = Map<dynamic, dynamic>.from(value);
            studentMap['nim'] ??= key.toString();
            list.add(Student.fromFirestore(studentMap));
          }
        });
        return list;
      }
      return [];
    } catch (e) {
      Logger.error('Error getting all students: $e');
      return [];
    }
  }

  static List<Student> _allStudentsCache = [];

  static Future<List<Student>> getStudentsPaginated(
      {int limit = 20, String? lastNodeKey}) async {
    try {
      // Fetch all data once (up to 2000 records) to avoid Firebase index rules issues
      if (lastNodeKey == null || _allStudentsCache.isEmpty) {
        final data = await _restGet(
            'students', {'orderBy': '"\$key"', 'limitToFirst': '2000'});

        if (data != null && data is Map) {
          final list = <Student>[];
          data.forEach((key, value) {
            if (value is Map) {
              final studentMap = Map<dynamic, dynamic>.from(value);
              studentMap['nim'] ??= key.toString();
              list.add(Student.fromFirestore(studentMap));
            }
          });
          
          // Default sort by name ascending
          list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
          _allStudentsCache = list;
        } else {
          _allStudentsCache = [];
        }
      }

      // Local pagination logic
      if (_allStudentsCache.isEmpty) return [];

      int startIndex = 0;
      if (lastNodeKey != null) {
        // Find the index of the last node and start from the next one
        startIndex = _allStudentsCache.indexWhere((s) => s.nim == lastNodeKey);
        if (startIndex != -1) {
          startIndex += 1;
        } else {
          startIndex = 0;
        }
      }

      if (startIndex >= _allStudentsCache.length) return [];
      
      return _allStudentsCache.skip(startIndex).take(limit).toList();
    } catch (e) {
      Logger.error('Error getting paginated students locally: $e');
      return [];
    }
  }

  static Future<List<Student>> searchStudentsByName(String query,
      {int limit = 50}) async {
    try {
      if (query.isEmpty) return await getStudentsPaginated(limit: limit);

      // Ensure cache is loaded
      if (_allStudentsCache.isEmpty) {
        await getStudentsPaginated(limit: 2000);
      }

      final q = query.toLowerCase();
      final results = _allStudentsCache.where((s) {
        return s.name.toLowerCase().contains(q) ||
               s.nim.toLowerCase().contains(q) ||
               s.vehicleNumber.toLowerCase().contains(q);
      }).take(limit).toList();
      
      return results;
    } catch (e) {
      Logger.error('Error searching students locally: $e');
      return [];
    }
  }

  static Future<bool> createStudent(Student student) async {
    final success = await _restPut('students/${student.nim}', student.toFirestore());
    if (success) {
      _allStudentsCache.add(student);
      _allStudentsCache.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      unawaited(LocalDatabaseService().insertOrUpdateStudent(student));
    }
    return success;
  }

  static Future<bool> updateStudent(Student student) async {
    final success = await _restPatch('students/${student.nim}', student.toFirestore());
    if (success) {
      final index = _allStudentsCache.indexWhere((s) => s.nim == student.nim);
      if (index != -1) {
        _allStudentsCache[index] = student;
        _allStudentsCache.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      }
      unawaited(LocalDatabaseService().insertOrUpdateStudent(student));
    }
    return success;
  }

  static Future<bool> deleteStudent(String nim) async {
    _studentCache.remove(nim);
    _cacheTimestamp.remove(nim);
    final success = await _restDelete('students/$nim');
    if (success) {
      _allStudentsCache.removeWhere((s) => s.nim == nim);
      unawaited(LocalDatabaseService().deleteStudent(nim));
    }
    return success;
  }

  static Future<bool> clearScanHistory() async {
    unawaited(LocalDatabaseService().clearScanHistory());
    return await _restDelete('scan_history');
  }
}
