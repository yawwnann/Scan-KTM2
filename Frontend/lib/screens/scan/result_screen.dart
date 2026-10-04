import 'package:flutter/material.dart';
import '../../models/student.dart';

class ResultScreen extends StatelessWidget {
  final Student student;
  final VoidCallback? onResultRendered;

  const ResultScreen({
    super.key,
    required this.student,
    this.onResultRendered,
  });

  @override
  Widget build(BuildContext context) {
    if (onResultRendered != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        onResultRendered!();
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hasil Scanning'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header dengan status berhasil
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: Column(
                children: [
                  const Icon(Icons.check_circle, size: 80, color: Colors.white),
                  const SizedBox(height: 15),
                  const Text(
                    'Data Ditemukan!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Waktu Scan: ${_formatDateTime(student.scanTime)}',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // Informasi Mahasiswa
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withValues(alpha: 0.1),
                    spreadRadius: 5,
                    blurRadius: 7,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.person,
                        color: Theme.of(context).colorScheme.primary,
                        size: 30,
                      ),
                      const SizedBox(width: 15),
                      const Text(
                        'Informasi Mahasiswa',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildInfoRow('NIM', student.nim),
                  _buildInfoRow('Nama', student.name),
                  _buildInfoRow('Fakultas', student.faculty),
                  _buildInfoRow('Program Studi', student.studyProgram),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Informasi Kendaraan
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withValues(alpha: 0.1),
                    spreadRadius: 5,
                    blurRadius: 7,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.directions_car,
                        color: Theme.of(context).colorScheme.primary,
                        size: 30,
                      ),
                      const SizedBox(width: 15),
                      const Text(
                        'Informasi Kendaraan',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildInfoRow('Nomor Plat', student.vehicleNumber),
                  _buildInfoRow('Jenis Kendaraan', student.vehicleBrand.isNotEmpty ? '${student.vehicleType} - ${student.vehicleBrand}' : student.vehicleType),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // Tombol aksi
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  // Tombol Scan Lagi
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      icon: const Icon(Icons.qr_code_scanner),
                      label: const Text('Scan KTM Lain'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 15),

                  // Tombol Share
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        _shareResult(context);
                      },
                      icon: const Icon(Icons.share),
                      label: const Text('Bagikan Hasil'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.primary,
                        side: BorderSide(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const Text(
            ': ',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  void _shareResult(BuildContext context) {
    final String shareText =
        '''
Data Mahasiswa UAD:
NIM: ${student.nim}
Nama: ${student.name}
Fakultas: ${student.faculty}
Program Studi: ${student.studyProgram}

Data Kendaraan:
Nomor Plat: ${student.vehicleNumber}
Jenis: ${student.vehicleBrand.isNotEmpty ? '${student.vehicleType} - ${student.vehicleBrand}' : student.vehicleType}

Waktu Scan: ${_formatDateTime(student.scanTime)}
    ''';

    // Untuk sementara, tampilkan dialog dengan data yang bisa di-copy
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Bagikan Hasil'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Data yang akan dibagikan:'),
              const SizedBox(height: 15),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  shareText,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Tutup'),
            ),
            ElevatedButton(
              onPressed: () {
                // Implementasi share yang sebenarnya bisa ditambahkan di sini
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Fitur share akan segera tersedia!'),
                  ),
                );
              },
              child: const Text('Bagikan'),
            ),
          ],
        );
      },
    );
  }
}
