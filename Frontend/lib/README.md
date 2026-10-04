# Struktur Direktori Lib

Struktur direktori `lib` telah dirapihkan dan diorganisir untuk meningkatkan maintainability dan scalability proyek.

## 📁 Struktur Direktori

```
lib/
├── 📁 config/                    # Konfigurasi aplikasi
│   ├── app_config.dart          # Konfigurasi umum aplikasi
│   ├── platform_config.dart     # Konfigurasi platform-specific
│   └── index.dart               # Export barrel file
│
├── 📁 constants/                 # Konstanta aplikasi
│   ├── 📁 theme/                # Konstanta tema
│   │   ├── colors.dart          # Definisi warna
│   │   └── index.dart           # Export barrel file
│   └── index.dart               # Export barrel file
│
├── 📁 data/                     # Data dan mock data
│   ├── demo_data.dart           # Data demo untuk development
│   └── index.dart               # Export barrel file
│
├── 📁 models/                   # Model data
│   ├── faculty_data.dart        # Model data fakultas
│   ├── scan_history.dart        # Model riwayat scan
│   ├── student.dart             # Model mahasiswa
│   └── index.dart               # Export barrel file
│
├── 📁 screens/                  # UI Screens
│   ├── 📁 auth/                 # Screens autentikasi
│   │   ├── auth_screen.dart     # Screen login/register
│   │   ├── splash_screen.dart   # Screen splash
│   │   └── index.dart           # Export barrel file
│   │
│   ├── 📁 navigation/           # Screens navigasi
│   │   ├── main_navigation_screen.dart  # Bottom navigation
│   │   └── index.dart           # Export barrel file
│   │
│   ├── 📁 profile/              # Screens profil
│   │   ├── profile_screen.dart  # Screen profil user
│   │   └── index.dart           # Export barrel file
│   │
│   ├── 📁 scan/                 # Screens scanning
│   │   ├── scan_screen.dart     # Screen barcode scanner
│   │   ├── ocr_screen.dart      # Screen OCR scanner
│   │   ├── result_screen.dart   # Screen hasil scan
│   │   ├── scan_history_screen.dart  # Screen riwayat scan
│   │   └── index.dart           # Export barrel file
│   │
│   ├── 📁 student/              # Screens manajemen mahasiswa
│   │   ├���─ student_list_screen.dart     # Screen daftar mahasiswa
│   │   ├── student_detail_screen.dart   # Screen detail mahasiswa
│   │   ├── add_edit_student_screen.dart # Screen tambah/edit mahasiswa
│   │   └── index.dart           # Export barrel file
│   │
│   └── index.dart               # Export barrel file
│
├── 📁 services/                 # Business logic dan API calls
│   ├── firebase_service.dart    # Service Firebase
│   ├── ocr_service.dart         # Service OCR
│   ├── student_service.dart     # Service mahasiswa
│   └── index.dart               # Export barrel file
│
├── 📁 utils/                    # Utility functions
│   ├── 📁 logging/              # Logging utilities
│   │   ├── logger.dart          # Logger utility
│   │   └─�� index.dart           # Export barrel file
│   └── index.dart               # Export barrel file
│
├── firebase_options.dart        # Konfigurasi Firebase
├── main.dart                    # Entry point aplikasi
└── index.dart                   # Main export barrel file
```

## 🎯 Prinsip Organisasi

### 1. **Feature-Based Organization**
- Screens dikelompokkan berdasarkan fitur (auth, student, scan, profile)
- Setiap fitur memiliki folder terpisah dengan file terkait

### 2. **Separation of Concerns**
- **Models**: Data structures dan business objects
- **Services**: Business logic dan external API calls
- **Screens**: UI components dan presentation logic
- **Utils**: Helper functions dan utilities
- **Config**: Application configuration
- **Constants**: Application constants

### 3. **Barrel Exports**
- Setiap folder memiliki `index.dart` untuk export
- Memudahkan import dengan path yang bersih
- Mengurangi coupling antar modul

## 📦 Import Guidelines

### ✅ Recommended Imports

```dart
// Import dari barrel files
import 'package:scan_ktm_project/screens/index.dart';
import 'package:scan_ktm_project/services/index.dart';
import 'package:scan_ktm_project/models/index.dart';

// Atau import spesifik
import 'package:scan_ktm_project/screens/student/index.dart';
import 'package:scan_ktm_project/services/firebase_service.dart';
```

### ❌ Avoid Direct Imports

```dart
// Hindari import langsung ke file spesifik
import 'package:scan_ktm_project/screens/student/student_list_screen.dart';
import 'package:scan_ktm_project/utils/logging/logger.dart';
```

## 🔄 Migration Notes

Semua import statements telah diperbarui untuk menggunakan struktur baru:

1. **Screens**: Dipindahkan ke sub-folder berdasarkan fitur
2. **Utils**: Logger dipindahkan ke `utils/logging/`
3. **Constants**: Colors dipindahkan ke `constants/theme/`
4. **Barrel Exports**: Ditambahkan di setiap folder

## 🚀 Benefits

1. **Better Organization**: Kode lebih terstruktur dan mudah ditemukan
2. **Scalability**: Mudah menambah fitur baru tanpa mengacaukan struktur
3. **Maintainability**: Perubahan pada satu fitur tidak mempengaruhi yang lain
4. **Team Collaboration**: Developer dapat bekerja pada fitur berbeda tanpa konflik
5. **Clean Imports**: Import statements lebih bersih dan konsisten

## 📝 Adding New Features

Ketika menambah fitur baru:

1. Buat folder baru di `screens/` untuk UI screens
2. Tambahkan models terkait di `models/`
3. Buat services di `services/` jika diperlukan
4. Tambahkan utilities di `utils/` jika diperlukan
5. Jangan lupa buat `index.dart` untuk barrel exports
6. Update main `index.dart` untuk include fitur baru

Struktur ini mengikuti best practices Flutter dan memudahkan pengembangan aplikasi yang scalable dan maintainable.