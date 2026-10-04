import 'package:flutter/material.dart';

/// Smart SafeArea widget yang dapat menyesuaikan dengan berbagai tipe navigasi Android
class SmartSafeArea extends StatelessWidget {
  final Widget child;
  final bool top;
  final bool bottom;
  final bool left;
  final bool right;
  final EdgeInsets? minimum;
  final bool maintainBottomViewPadding;

  const SmartSafeArea({
    super.key,
    required this.child,
    this.top = true,
    this.bottom = true,
    this.left = true,
    this.right = true,
    this.minimum,
    this.maintainBottomViewPadding = false,
  });

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final viewInsets = mediaQuery.viewInsets;
    final viewPadding = mediaQuery.viewPadding;
    final padding = mediaQuery.padding;

    // Deteksi jenis navigasi Android
    final hasSystemNavBar = padding.bottom > 0;
    final isGestureNav = hasSystemNavBar && padding.bottom < 30;
    final hasKeyboard = viewInsets.bottom > 0;

    // Kalkulasi padding yang smart
    final effectivePadding = EdgeInsets.only(
      top: top ? (minimum?.top ?? 0).clamp(0, padding.top) : 0,
      bottom: _calculateBottomPadding(
        hasSystemNavBar,
        isGestureNav,
        hasKeyboard,
        padding.bottom,
        viewInsets.bottom,
        viewPadding.bottom,
      ),
      left: left ? (minimum?.left ?? 0).clamp(0, padding.left) : 0,
      right: right ? (minimum?.right ?? 0).clamp(0, padding.right) : 0,
    );

    return Padding(padding: effectivePadding, child: child);
  }

  double _calculateBottomPadding(
    bool hasSystemNavBar,
    bool isGestureNav,
    bool hasKeyboard,
    double systemPadding,
    double keyboardHeight,
    double viewPadding,
  ) {
    if (!bottom) return 0;

    final minPadding = minimum?.bottom ?? 0;

    // Jika ada keyboard, gunakan view padding
    if (hasKeyboard && maintainBottomViewPadding) {
      return minPadding.clamp(0, viewPadding);
    }

    // Jika tidak ada system navigation bar
    if (!hasSystemNavBar) {
      return minPadding;
    }

    // Untuk gesture navigation, gunakan padding minimal
    if (isGestureNav) {
      return minPadding.clamp(0, systemPadding * 0.5);
    }

    // Untuk button navigation, gunakan system padding penuh
    return minPadding.clamp(0, systemPadding);
  }
}

/// Extension untuk MediaQuery helpers
extension MediaQueryExtension on MediaQuery {
  /// Cek apakah menggunakan gesture navigation (Android 10+)
  bool get isUsingGestureNavigation {
    return data.padding.bottom > 0 && data.padding.bottom < 30;
  }

  /// Cek apakah memiliki system navigation bar
  bool get hasSystemNavigationBar {
    return data.padding.bottom > 0;
  }

  /// Get navigation bar height yang aman
  double get safeNavigationBarHeight {
    if (!hasSystemNavigationBar) return 0;
    return isUsingGestureNavigation
        ? data.padding.bottom * 0.5
        : data.padding.bottom;
  }
}
