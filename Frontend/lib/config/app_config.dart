import 'package:shared_preferences/shared_preferences.dart';

class AppConfig {
  // Base URL untuk Express.js Backend di komputer lokal (Akses dari HP Fisik via Wi-Fi)
  static const String defaultBaseUrl = 'http://192.168.1.5:5000/api/v1';
  static String _activeBaseUrl = defaultBaseUrl;

  static String get baseUrl => _activeBaseUrl;

  /// Memuat custom base URL dari local storage jika user mengubah IP server
  static Future<void> initConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUrl = prefs.getString('custom_backend_url');
      if (savedUrl != null && savedUrl.isNotEmpty) {
        _activeBaseUrl = savedUrl;
      }
    } catch (_) {}
  }

  /// Update backend server IP/URL saat testing di jaringan Wi-Fi berbeda
  static Future<void> updateBaseUrl(String newUrl) async {
    _activeBaseUrl = newUrl.trim();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('custom_backend_url', _activeBaseUrl);
    } catch (_) {}
  }

  // Timeout untuk HTTP requests (dalam detik)
  static const int httpTimeout = 15;

  // Nama aplikasi
  static const String appName = 'STNK Check UAD';

  // Versi aplikasi
  static const String appVersion = '1.0.0';

  // Konfigurasi untuk development
  static const bool isDevelopment = false;

  // Log level
  static const String logLevel = 'INFO';

  // Konfigurasi scanner
  static const bool enableAutoFocus = true;
  static const bool enableFlash = false;

  // Konfigurasi UI
  static const double defaultPadding = 20.0;
  static const double defaultRadius = 20.0;

  // Warna tema
  static const int primaryColor = 0xFFFF6B35; // Orange Primary
  static const int accentColor = 0xFFFF8A65; // Orange Light
  static const int successColor = 0xFF4CAF50; // Green
  static const int errorColor = 0xFFF44336; // Red

  // Endpoints API
  static const String studentsEndpoint = '/students';
  static const String scanHistoryEndpoint = '/scan-history';
  static const String benchmarksEndpoint = '/benchmarks';
  static const String authEndpoint = '/auth';

  // Format tanggal
  static const String dateFormat = 'dd/MM/yyyy HH:mm';

  // Pesan error
  static const String networkErrorMessage =
      'Tidak dapat terhubung ke server backend. Periksa koneksi Wi-Fi atau IP server.';
  static const String dataNotFoundMessage =
      'Data tidak ditemukan dalam sistem.';
  static const String generalErrorMessage =
      'Terjadi kesalahan. Silakan coba lagi.';

  // Pesan sukses
  static const String scanSuccessMessage = 'Data berhasil ditemukan!';
  static const String saveSuccessMessage = 'Data berhasil disimpan!';
}
