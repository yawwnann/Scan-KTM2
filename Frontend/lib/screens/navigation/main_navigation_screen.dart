import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../scan/scan_screen.dart';
import '../scan/ocr_screen.dart';
import '../student/student_list_screen.dart';
import '../scan/scan_history_screen.dart';
import '../profile/profile_screen.dart';
import '../../services/connectivity_service.dart';
import '../../utils/ui/responsive_helper.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen>
    with AutomaticKeepAliveClientMixin {
  int _currentIndex = 2; // Set barcode sebagai halaman default

  final List<Widget> _screens = [
    const OCRScreen(key: ValueKey('ocr')),
    const StudentListScreen(key: ValueKey('student_list')),
    const ScanScreen(key: ValueKey('scan')),
    const ScanHistoryScreen(key: ValueKey('scan_history')),
    const ProfileScreen(key: ValueKey('profile')),
  ];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
  }

  Future<void> _checkConnectivity() async {
    final hasConnection = await ConnectivityService.hasConnection();
    if (!hasConnection && mounted) {
      _showNoConnectionDialog();
    }
  }

  void _showNoConnectionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          icon: Icon(
            Icons.wifi_off_rounded,
            size: 48,
            color: Theme.of(context).colorScheme.error,
          ),
          title: const Text(
            'Tidak Ada Koneksi Internet',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'Aplikasi memerlukan koneksi internet untuk berfungsi dengan baik. Silakan periksa koneksi Anda dan coba lagi.',
            textAlign: TextAlign.center,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _checkConnectivity();
              },
              child: const Text('Coba Lagi'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final colorScheme = Theme.of(context).colorScheme;
    final hasSystemNavBar = ResponsiveHelper.hasSystemNavigationBar(context);
    final bottomPadding = ResponsiveHelper.getSafeBottomPadding(context);
    final isGestureNav = ResponsiveHelper.isUsingGestureNavigation(context);

    // Update system UI overlay untuk halaman ini
    ResponsiveHelper.updateSystemUIOverlay(
      systemNavigationBarColor: colorScheme.surface,
    );

    return Scaffold(
      backgroundColor: colorScheme.surface,
      extendBody: true, // Extend body behind system navigation
      body: SafeArea(
        bottom: false, // Biarkan body extend ke system nav area
        child: IndexedStack(index: _currentIndex, children: _screens),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(
        colorScheme,
        hasSystemNavBar,
        bottomPadding,
        isGestureNav,
      ),
    );
  }

  Widget _buildBottomNavigationBar(
    ColorScheme colorScheme,
    bool hasSystemNavBar,
    double bottomPadding,
    bool isGestureNav,
  ) {
    return Container(
      // Tinggi responsif berdasarkan system navigation
      height: _calculateBottomNavHeight(
        hasSystemNavBar,
        bottomPadding,
        isGestureNav,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        children: [
          // Main navigation content
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // OCR
                _buildNavItem(
                  icon: Icons.text_fields_outlined,
                  activeIcon: Icons.text_fields,
                  label: 'OCR',
                  index: 0,
                  colorScheme: colorScheme,
                ),
                // Mahasiswa
                _buildNavItem(
                  icon: Icons.group_outlined,
                  activeIcon: Icons.group,
                  label: 'Mahasiswa',
                  index: 1,
                  colorScheme: colorScheme,
                ),
                // Barcode (Center - Floating)
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: GestureDetector(
                    onTap: () => _onItemTapped(2),
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            colorScheme.primary,
                            colorScheme.primary.withOpacity(0.8),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.primary.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.qr_code_scanner,
                        color: colorScheme.onPrimary,
                        size: 28,
                      ),
                    ),
                  ),
                ),
                // Riwayat
                _buildNavItem(
                  icon: Icons.access_time_outlined,
                  activeIcon: Icons.access_time_filled,
                  label: 'Riwayat',
                  index: 3,
                  colorScheme: colorScheme,
                ),
                // Profil
                _buildNavItem(
                  icon: Icons.person_outlined,
                  activeIcon: Icons.person,
                  label: 'Profil',
                  index: 4,
                  colorScheme: colorScheme,
                ),
              ],
            ),
          ),
          // Bottom padding for system navigation bar
          _buildBottomPadding(hasSystemNavBar, bottomPadding, isGestureNav),
        ],
      ),
    );
  }

  double _calculateBottomNavHeight(
    bool hasSystemNavBar,
    double bottomPadding,
    bool isGestureNav,
  ) {
    const baseHeight = 80.0;

    if (!hasSystemNavBar) {
      return baseHeight + 10; // Extra padding when no system nav
    }

    if (isGestureNav) {
      return baseHeight + bottomPadding + 5; // Less padding for gesture nav
    }

    return baseHeight + bottomPadding; // Standard height + system nav padding
  }

  Widget _buildBottomPadding(
    bool hasSystemNavBar,
    double bottomPadding,
    bool isGestureNav,
  ) {
    if (!hasSystemNavBar) {
      return const SizedBox(height: 10); // Extra padding when no system nav
    }

    if (isGestureNav) {
      return SizedBox(
        height: bottomPadding + 5,
      ); // Slightly more padding for gesture nav
    }

    return SizedBox(height: bottomPadding); // Standard system nav padding
  }

  Widget _buildNavItem({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required int index,
    required ColorScheme colorScheme,
  }) {
    final bool isSelected = _currentIndex == index;

    return Expanded(
      child: GestureDetector(
        onTap: () => _onItemTapped(index),
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isSelected ? activeIcon : icon,
                size: 24,
                color: isSelected
                    ? colorScheme.primary
                    : colorScheme.onSurface.withOpacity(0.6),
              ),
              const SizedBox(height: 4),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected
                        ? colorScheme.primary
                        : colorScheme.onSurface.withOpacity(0.6),
                    height: 1.0,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onItemTapped(int index) {
    if (_currentIndex != index && mounted) {
      setState(() {
        _currentIndex = index;
      });
    }
  }
}
