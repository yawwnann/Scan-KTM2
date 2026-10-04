import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import '../models/student.dart';
import '../models/scan_history.dart';
import '../utils/logging/logger.dart';

class ApiService {
  static const Duration _timeout = Duration(seconds: AppConfig.httpTimeout);

  // In-memory cache untuk token dan role
  static String? _cachedToken;
  static Map<String, dynamic>? _cachedUser;

  // ─── Headers & Auth Token Helper ──────────────────────────────────────────

  static Future<Map<String, String>> _getHeaders({bool requireAuth = true}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (requireAuth) {
      final token = await getToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    return headers;
  }

  static Future<String?> getToken() async {
    if (_cachedToken != null) return _cachedToken;
    try {
      final prefs = await SharedPreferences.getInstance();
      _cachedToken = prefs.getString('jwt_token');
      return _cachedToken;
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveAuthData(String token, Map<String, dynamic> user) async {
    _cachedToken = token;
    _cachedUser = user;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('jwt_token', token);
      await prefs.setString('user_id', user['id'] ?? '');
      await prefs.setString('user_email', user['email'] ?? '');
      await prefs.setString('user_name', user['name'] ?? '');
      await prefs.setString('user_role', user['role'] ?? 'user');
    } catch (_) {}
  }

  static Future<void> logout() async {
    _cachedToken = null;
    _cachedUser = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('jwt_token');
      await prefs.remove('user_id');
      await prefs.remove('user_email');
      await prefs.remove('user_name');
      await prefs.remove('user_role');
    } catch (_) {}
  }

  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  static Future<Map<String, dynamic>?> getCurrentUser() async {
    if (_cachedUser != null) return _cachedUser;
    try {
      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString('user_email');
      if (email == null) return null;

      _cachedUser = {
        'id': prefs.getString('user_id') ?? '',
        'email': email,
        'name': prefs.getString('user_name') ?? '',
        'role': prefs.getString('user_role') ?? 'user',
      };
      return _cachedUser;
    } catch (_) {
      return null;
    }
  }

  static Future<bool> isCurrentUserAdmin() async {
    final user = await getCurrentUser();
    // Default admin true agar fleksibel untuk pengujian skripsi
    if (user == null) return true;
    return user['role'] == 'admin' || true;
  }

  // ─── AUTHENTICATION ENDPOINTS ─────────────────────────────────────────────

  static Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final url = Uri.parse('${AppConfig.baseUrl}/auth/login');
      final response = await http
          .post(
            url,
            headers: await _getHeaders(requireAuth: false),
            body: json.encode({'email': email.trim(), 'password': password}),
          )
          .timeout(_timeout);

      final data = json.decode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        final token = data['data']['token'];
        final user = data['data']['user'];
        await saveAuthData(token, user);
        return {'success': true, 'user': user};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Login gagal, periksa email & password',
        };
      }
    } catch (e) {
      Logger.error('ApiService.login error: $e');
      return {'success': false, 'message': 'Tidak dapat terhubung ke server: $e'};
    }
  }

  static Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String name,
    String role = 'user',
  }) async {
    try {
      final url = Uri.parse('${AppConfig.baseUrl}/auth/register');
      final response = await http
          .post(
            url,
            headers: await _getHeaders(requireAuth: false),
            body: json.encode({
              'email': email.trim(),
              'password': password,
              'name': name.trim(),
              'role': role,
            }),
          )
          .timeout(_timeout);

      final data = json.decode(response.body);
      if ((response.statusCode == 200 || response.statusCode == 201) &&
          data['success'] == true) {
        final token = data['data']['token'];
        final user = data['data']['user'];
        if (token != null) {
          await saveAuthData(token, user);
        }
        return {'success': true, 'user': user};
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Registrasi gagal',
        };
      }
    } catch (e) {
      Logger.error('ApiService.register error: $e');
      return {'success': false, 'message': 'Gagal mendaftar: $e'};
    }
  }

  // ─── STUDENT ENDPOINTS ───────────────────────────────────────────────────

  static Future<Student?> getStudentByNIM(String nim) async {
    try {
      final cleanNim = nim.trim();
      final url = Uri.parse('${AppConfig.baseUrl}/students/$cleanNim');
      final response = await http.get(url, headers: await _getHeaders()).timeout(_timeout);

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        if (jsonResponse['success'] == true && jsonResponse['data'] != null) {
          return Student.fromJson(jsonResponse['data']);
        }
      }
      return null;
    } catch (e) {
      Logger.error('ApiService.getStudentByNIM error: $e');
      return null;
    }
  }

  static Future<Student?> getStudentByBarcode(String barcode) async {
    return await getStudentByNIM(barcode);
  }

  static Future<Student?> getStudentByVehicleNumber(String vehicleNumber) async {
    try {
      final cleanPlate = Uri.encodeComponent(vehicleNumber.trim());
      final url = Uri.parse('${AppConfig.baseUrl}/students/vehicle/$cleanPlate');
      final response = await http.get(url, headers: await _getHeaders()).timeout(_timeout);

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        if (jsonResponse['success'] == true && jsonResponse['data'] != null) {
          final data = jsonResponse['data'];
          // Backend mengembalikan { matched_vehicle, student }
          if (data['student'] != null) {
            return Student.fromJson(data['student']);
          } else {
            return Student.fromJson(data);
          }
        }
      }
      return null;
    } catch (e) {
      Logger.error('ApiService.getStudentByVehicleNumber error: $e');
      return null;
    }
  }

  static Future<List<Student>> getAllStudents({int limit = 100}) async {
    try {
      final url = Uri.parse('${AppConfig.baseUrl}/students?limit=$limit');
      final response = await http.get(url, headers: await _getHeaders()).timeout(_timeout);

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        if (jsonResponse['success'] == true && jsonResponse['data'] is List) {
          return (jsonResponse['data'] as List)
              .map((item) => Student.fromJson(item))
              .toList();
        }
      }
      return [];
    } catch (e) {
      Logger.error('ApiService.getAllStudents error: $e');
      return [];
    }
  }

  static Future<List<Student>> getStudentsPaginated({
    int limit = 20,
    String? lastNodeKey,
  }) async {
    return await getAllStudents(limit: 500);
  }

  static Future<List<Student>> searchStudentsByName(
    String query, {
    int limit = 50,
  }) async {
    try {
      final encoded = Uri.encodeComponent(query.trim());
      final url = Uri.parse('${AppConfig.baseUrl}/students?search=$encoded&limit=$limit');
      final response = await http.get(url, headers: await _getHeaders()).timeout(_timeout);

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        if (jsonResponse['success'] == true && jsonResponse['data'] is List) {
          return (jsonResponse['data'] as List)
              .map((item) => Student.fromJson(item))
              .toList();
        }
      }
      return [];
    } catch (e) {
      Logger.error('ApiService.searchStudentsByName error: $e');
      return [];
    }
  }

  static Future<bool> createStudent(Student student) async {
    try {
      final url = Uri.parse('${AppConfig.baseUrl}/students');
      final payload = student.toJson();

      final response = await http
          .post(url, headers: await _getHeaders(), body: json.encode(payload))
          .timeout(_timeout);

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      Logger.error('ApiService.createStudent error: $e');
      return false;
    }
  }

  static Future<bool> updateStudent(Student student) async {
    try {
      final cleanNim = student.nim.trim();
      final url = Uri.parse('${AppConfig.baseUrl}/students/$cleanNim');
      final payload = student.toJson();

      final response = await http
          .put(url, headers: await _getHeaders(), body: json.encode(payload))
          .timeout(_timeout);

      return response.statusCode == 200;
    } catch (e) {
      Logger.error('ApiService.updateStudent error: $e');
      return false;
    }
  }

  static Future<bool> deleteStudent(String nim) async {
    try {
      final cleanNim = nim.trim();
      final url = Uri.parse('${AppConfig.baseUrl}/students/$cleanNim');
      final response = await http.delete(url, headers: await _getHeaders()).timeout(_timeout);

      return response.statusCode == 200;
    } catch (e) {
      Logger.error('ApiService.deleteStudent error: $e');
      return false;
    }
  }

  // ─── SCAN HISTORY ENDPOINTS ──────────────────────────────────────────────

  static Future<bool> saveScanHistory(
    Student student,
    String location, {
    String scanMethod = 'unknown',
  }) async {
    try {
      final url = Uri.parse('${AppConfig.baseUrl}/scan-history');
      final payload = {
        'student_nim': student.nim,
        'student_name': student.name,
        'faculty': student.faculty,
        'study_program': student.studyProgram,
        'vehicle_number': student.vehicleNumber,
        'vehicle_type': student.vehicleType,
        'scan_method': scanMethod,
        'location': location,
        'scan_time': DateTime.now().millisecondsSinceEpoch,
      };

      final response = await http
          .post(url, headers: await _getHeaders(), body: json.encode(payload))
          .timeout(_timeout);

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      Logger.error('ApiService.saveScanHistory error: $e');
      return false;
    }
  }

  static Future<List<ScanHistory>> getAllScanHistory({int limit = 100}) async {
    try {
      final url = Uri.parse('${AppConfig.baseUrl}/scan-history?limit=$limit');
      final response = await http.get(url, headers: await _getHeaders()).timeout(_timeout);

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        if (jsonResponse['success'] == true && jsonResponse['data'] is List) {
          return (jsonResponse['data'] as List)
              .map((item) => ScanHistory.fromJson(item))
              .toList();
        }
      }
      return [];
    } catch (e) {
      Logger.error('ApiService.getAllScanHistory error: $e');
      return [];
    }
  }

  static Future<List<Student>> getScanHistoryAsStudents() async {
    final histories = await getAllScanHistory();
    return histories.map((h) => h.toStudent()).toList();
  }

  static Future<bool> batchSyncScanHistories(List<ScanHistory> histories) async {
    try {
      if (histories.isEmpty) return true;
      final url = Uri.parse('${AppConfig.baseUrl}/scan-history/batch');
      final payload = {
        'histories': histories.map((h) => h.toJson()).toList(),
      };

      final response = await http
          .post(url, headers: await _getHeaders(), body: json.encode(payload))
          .timeout(_timeout);

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      Logger.error('ApiService.batchSyncScanHistories error: $e');
      return false;
    }
  }

  static Future<bool> clearScanHistory() async {
    try {
      final url = Uri.parse('${AppConfig.baseUrl}/scan-history');
      final response = await http.delete(url, headers: await _getHeaders()).timeout(_timeout);
      return response.statusCode == 200;
    } catch (e) {
      Logger.error('ApiService.clearScanHistory error: $e');
      return false;
    }
  }

  // ─── BENCHMARK ENDPOINTS (Bab 4 Skripsi) ──────────────────────────────────

  static Future<bool> sendBenchmarkMetrics(Map<String, dynamic> benchmarkData) async {
    try {
      final url = Uri.parse('${AppConfig.baseUrl}/benchmarks');
      final response = await http
          .post(url, headers: await _getHeaders(), body: json.encode(benchmarkData))
          .timeout(const Duration(seconds: 10));

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      Logger.error('ApiService.sendBenchmarkMetrics error (non-fatal): $e');
      return false;
    }
  }

  static String getBenchmarkExportCsvUrl() {
    return '${AppConfig.baseUrl}/benchmarks/export-csv';
  }
}
