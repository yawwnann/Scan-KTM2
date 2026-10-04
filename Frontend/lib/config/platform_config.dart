import 'package:flutter/foundation.dart';
import '../utils/logging/logger.dart';

class PlatformConfig {
  // Deteksi platform
  static bool get isWeb => kIsWeb;
  static bool get isMobile => !kIsWeb;

  // Konfigurasi berdasarkan platform
  static bool get enableScanner => isMobile;
  static bool get enableCamera => isMobile;

  // Pesan untuk platform yang tidak didukung
  static String get unsupportedPlatformMessage => isWeb
      ? 'Scanner tidak tersedia di platform web. Gunakan aplikasi mobile untuk scanning KTM.'
      : 'Platform tidak didukung';

  // Tampilkan warning jika di web
  static void showPlatformWarning() {
    if (isWeb) {
      Logger.warning(
        'Aplikasi ini dirancang untuk mobile. Scanner tidak akan berfungsi di web.',
      );
    }
  }
}
