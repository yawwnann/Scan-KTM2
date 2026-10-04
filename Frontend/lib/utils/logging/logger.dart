import 'package:flutter/foundation.dart';
import '../../config/app_config.dart';

class Logger {
  static void debug(String message) {
    if (AppConfig.isDevelopment && kDebugMode) {
      debugPrint('🐛 [DEBUG] $message');
    }
  }

  static void info(String message) {
    if (AppConfig.isDevelopment && kDebugMode) {
      debugPrint('ℹ️ [INFO] $message');
    }
  }

  static void warning(String message) {
    if (kDebugMode) {
      debugPrint('⚠️ [WARNING] $message');
    }
  }

  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      debugPrint('❌ [ERROR] $message');
      if (error != null) {
        debugPrint('Error details: $error');
      }
      if (stackTrace != null) {
        debugPrint('Stack trace: $stackTrace');
      }
    }
  }

  static void network(String message) {
    if (AppConfig.isDevelopment && kDebugMode) {
      debugPrint('🌐 [NETWORK] $message');
    }
  }

  static void scanner(String message) {
    if (AppConfig.isDevelopment && kDebugMode) {
      debugPrint('📷 [SCANNER] $message');
    }
  }
}
