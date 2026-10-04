import 'package:flutter/material.dart';

class ScannerOverlay extends StatelessWidget {
  final Rect scanWindow;
  final bool isScanning;
  final bool isError;
  final String? errorMessage;
  final VoidCallback onRetry;

  const ScannerOverlay({
    super.key,
    required this.scanWindow,
    required this.isScanning,
    this.isError = false,
    this.errorMessage,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Semi-transparent overlay with cutout
        ColorFiltered(
          colorFilter: ColorFilter.mode(
            Colors.black.withValues(alpha: 0.6),
            BlendMode.srcOut,
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Container(
                decoration: const BoxDecoration(
                  color: Colors.black,
                  backgroundBlendMode: BlendMode.dstOut,
                ),
              ),
              Positioned.fromRect(
                rect: scanWindow,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Scanning indicators
        if (isScanning && !isError)
          Positioned(
            top: scanWindow.center.dy - 20,
            left: 0,
            right: 0,
            child: const Center(
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 3,
              ),
            ),
          ),

        if (isError)
          Positioned(
            top: scanWindow.center.dy - 40,
            left: 0,
            right: 0,
            child: Center(
              child: Column(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 40),
                  const SizedBox(height: 8),
                  Text(
                    errorMessage ?? 'Terjadi kesalahan',
                    style: const TextStyle(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: onRetry,
                    child: const Text('Coba Lagi'),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
