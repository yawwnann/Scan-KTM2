# STNK Check UAD

Aplikasi Flutter untuk melakukan scanning KTM (Kartu Tanda Mahasiswa) dan menampilkan data mahasiswa beserta informasi kendaraan di Universitas Ahmad Dahlan.

## Fitur Utama

- **Scanning Barcode KTM**: Menggunakan kamera untuk scan barcode pada KTM mahasiswa
- **Input Manual**: Opsi untuk input NIM atau nomor plat secara manual
- **Data Mahasiswa**: Menampilkan informasi lengkap mahasiswa (NIM, nama, fakultas, program studi)
- **Data Kendaraan**: Menampilkan informasi kendaraan (nomor plat, jenis kendaraan)
- **Riwayat Scanning**: Menyimpan data scanning untuk keperluan audit
- **UI Modern**: Interface yang user-friendly dengan Material Design 3

## Struktur Aplikasi

```
lib/
├── main.dart                 # Entry point aplikasi
├── models/
│   └── student.dart         # Model data mahasiswa
├── services/
│   └── student_service.dart # Service untuk API calls
└── screens/
    ├── scan_screen.dart     # Halaman utama scanning
    └── result_screen.dart   # Halaman hasil scanning
```

## Dependensi

- `mobile_scanner`: Untuk scanning barcode/QR code
- `http`: Untuk HTTP requests ke API kampus
- `shared_preferences`: Untuk local storage
- `qr_flutter`: Untuk generate QR code (opsional)

## Setup dan Instalasi

### 1. Install Dependensi
```bash
flutter pub get
```

### 2. Konfigurasi API
Update file `lib/services/student_service.dart` dengan URL API kampus Anda:
```dart
static const String baseUrl = 'https://api-kampus-uad.com/api';
```

### 3. Izin Aplikasi
Aplikasi memerlukan izin:
- **Kamera**: Untuk scanning barcode
- **Internet**: Untuk koneksi ke API kampus

### 4. Build dan Run
```bash
flutter run
```

## Penggunaan

### Scanning KTM
1. Buka aplikasi
2. Arahkan kamera ke barcode pada KTM
3. Pastikan barcode terlihat jelas dalam frame
4. Aplikasi akan otomatis mendeteksi dan memproses barcode

### Input Manual
1. Klik tombol "Input Manual NIM/Plat"
2. Pilih jenis input (NIM atau Nomor Plat)
3. Masukkan data yang ingin dicari
4. Klik "Cari"

### Hasil Scanning
Setelah scanning berhasil, aplikasi akan menampilkan:
- Informasi mahasiswa (NIM, nama, fakultas, program studi)
- Informasi kendaraan (nomor plat, jenis kendaraan)
- Waktu scanning
- Tombol untuk scan ulang atau bagikan hasil

## API Endpoints

Aplikasi menggunakan endpoint berikut:

- `GET /api/students/{barcode}` - Mendapatkan data berdasarkan barcode
- `GET /api/students/nim/{nim}` - Mendapatkan data berdasarkan NIM
- `GET /api/students/vehicle/{vehicleNumber}` - Mendapatkan data berdasarkan nomor plat
- `POST /api/scan-history` - Menyimpan riwayat scanning

## Format Data Mahasiswa

```json
{
  "nim": "12345678",
  "name": "Nama Mahasiswa",
  "faculty": "Fakultas Teknologi Industri",
  "study_program": "Teknik Informatika",
  "vehicle_number": "AB 1234 CD",
  "vehicle_type": "Motor"
}
```

## Pengembangan

### Menambah Fitur Baru
1. Buat model baru di folder `models/`
2. Buat service baru di folder `services/`
3. Buat screen baru di folder `screens/`
4. Update routing di `main.dart`

### Testing
```bash
flutter test
```

## Troubleshooting

### Kamera Tidak Berfungsi
- Pastikan izin kamera sudah diberikan
- Restart aplikasi setelah memberikan izin

### API Error
- Periksa koneksi internet
- Pastikan URL API sudah benar
- Periksa response dari server

### Build Error
- Jalankan `flutter clean`
- Jalankan `flutter pub get`
- Pastikan semua dependensi kompatibel

## Kontribusi

Untuk berkontribusi pada pengembangan aplikasi:
1. Fork repository
2. Buat branch fitur baru
3. Commit perubahan
4. Push ke branch
5. Buat Pull Request

## Lisensi

Aplikasi ini dikembangkan untuk Universitas Ahmad Dahlan.

## Kontak

Untuk pertanyaan atau dukungan teknis, silakan hubungi tim pengembang UAD.
