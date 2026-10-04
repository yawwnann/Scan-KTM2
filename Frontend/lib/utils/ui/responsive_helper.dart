import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ResponsiveHelper {
  // Check if device has system navigation bar
  static bool hasSystemNavigationBar(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return mediaQuery.padding.bottom > 0;
  }

  // Get safe bottom padding
  static double getSafeBottomPadding(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return mediaQuery.padding.bottom;
  }

  // Get screen height excluding system bars
  static double getAvailableHeight(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return mediaQuery.size.height -
        mediaQuery.padding.top -
        mediaQuery.padding.bottom;
  }

  // Update system UI overlay style
  static void updateSystemUIOverlay({
    Color statusBarColor = Colors.transparent,
    Brightness statusBarIconBrightness = Brightness.dark,
    Color? systemNavigationBarColor,
    Brightness systemNavigationBarIconBrightness = Brightness.dark,
  }) {
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: statusBarColor,
        statusBarIconBrightness: statusBarIconBrightness,
        systemNavigationBarColor: systemNavigationBarColor ?? Colors.white,
        systemNavigationBarIconBrightness: systemNavigationBarIconBrightness,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
    );
  }

  // Edge to edge configuration
  static void enableEdgeToEdge() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  // Calculate responsive bottom navigation height
  static double getBottomNavigationHeight(BuildContext context) {
    final hasSystemNav = hasSystemNavigationBar(context);
    final bottomPadding = getSafeBottomPadding(context);

    if (hasSystemNav) {
      return 80 + bottomPadding; // Standard height + system nav padding
    } else {
      return 90; // Slightly taller when no system navigation
    }
  }

  // Get responsive padding for content
  static EdgeInsets getContentPadding(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return EdgeInsets.only(
      top: mediaQuery.padding.top,
      left: 16,
      right: 16,
      bottom: 16,
    );
  }

  // Check if using gesture navigation (Android 10+)
  static bool isUsingGestureNavigation(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    // Gesture navigation typically has smaller bottom padding
    return mediaQuery.padding.bottom > 0 && mediaQuery.padding.bottom < 30;
  }
}
