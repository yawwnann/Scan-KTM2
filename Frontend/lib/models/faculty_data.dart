class FacultyData {
  static const Map<String, Map<String, dynamic>> uadData = {
    "Universitas Ahmad Dahlan": {
      "Fakultas Keguruan dan Ilmu Pendidikan": {
        "kode": "FKIP",
        "Program Sarjana": [
          "Bimbingan dan Konseling",
          "Pendidikan Bahasa dan Sastra Indonesia",
          "Pendidikan Bahasa Inggris",
          "Pendidikan Biologi",
          "Pendidikan Fisika",
          "Pendidikan Guru PAUD",
          "Pendidikan Guru Sekolah Dasar",
          "Pendidikan Matematika",
          "Pendidikan Pancasila dan Kewarganegaraan",
          "Pendidikan Vokasional Teknik Elektronika",
          "Pendidikan Vokasional Teknologi Otomotif",
        ],
        "Program Magister": [
          "Magister Bimbingan dan Konseling",
          "Magister Manajemen Pendidikan",
          "Magister Pendidikan Bahasa Inggris",
          "Magister Pendidikan Fisika",
          "Magister Pendidikan Guru Vokasi",
          "Magister Pendidikan Matematika",
        ],
        "Program Doktor Pendidikan": ["Program Doktor Pendidikan"],
        "Program Profesi": ["Pendidikan Profesi Guru"],
      },
      "Fakultas Ekonomi dan Bisnis": {
        "kode": "FEB",
        "Program Sarjana Terapan": ["Bisnis Jasa Makanan"],
        "Program Sarjana": ["Akuntansi", "Ekonomi Pembangunan", "Manajemen"],
        "Program Magister": ["Magister Manajemen"],
      },
      "Fakultas Psikologi": {
        "kode": "FPsi",
        "Program Sarjana": ["Psikologi"],
        "Program Magister": ["Magister Psikologi Sains"],
        "Program Profesi": ["Pendidikan Profesi Psikologi"],
      },
      "Fakultas Sains dan Teknologi Terapan": {
        "kode": "FAST",
        "Program Sarjana": [
          "Biologi",
          "Fisika",
          "Matematika",
          "Sistem Informasi",
        ],
      },
      "Fakultas Teknologi Industri": {
        "kode": "FTI",
        "Program Sarjana": [
          "Informatika",
          "Teknik Industri",
          "Teknik Kimia",
          "Teknik Elektro",
          "Teknologi Pangan",
        ],
        "Program Magister": [
          "Magister Informatika",
          "Magister Teknik Kimia",
          "Magister Teknik Elektro",
        ],
        "Program Doktoral": ["Doktor Informatika"],
      },
      "Fakultas Farmasi": {
        "kode": "FFarm",
        "Program Sarjana": ["Farmasi"],
        "Program Magister": ["Magister Farmasi"],
        "Program Doktoral": ["Doktor Ilmu Farmasi"],
        "Program Profesi": ["Pendidikan Profesi Apoteker"],
      },
      "Fakultas Hukum": {
        "kode": "FH",
        "Program Sarjana": ["Hukum"],
        "Program Magister": ["Magister Hukum"],
      },
      "Fakultas Sastra, Budaya, dan Komunikasi": {
        "kode": "FSBK",
        "Program Sarjana": [
          "Sastra Inggris",
          "Sastra Indonesia",
          "Ilmu Komunikasi",
        ],
      },
      "Fakultas Agama Islam": {
        "kode": "FAI",
        "Program Sarjana": [
          "Bahasa dan Sastra Arab",
          "Ilmu Hadis",
          "Pendidikan Agama Islam",
          "Perbankan Syariah",
        ],
        "Program Magister": ["Magister Pendidikan Agama Islam"],
        "Program Doktoral": ["Doktor Studi Islam"],
      },
      "Fakultas Kesehatan Masyarakat": {
        "kode": "FKM",
        "Program Sarjana": ["Kesehatan Masyarakat", "Gizi"],
        "Program Magister": ["Magister Kesehatan Masyarakat"],
      },
      "Fakultas Kedokteran": {
        "kode": "FK",
        "Program Sarjana": ["Kedokteran"],
        "Program Profesi": ["Pendidikan Profesi Dokter"],
      },
    },
  };

  // Get list of faculties
  static List<String> getFaculties() {
    return uadData["Universitas Ahmad Dahlan"]!.keys.toList();
  }

  // Get faculty code
  static String getFacultyCode(String facultyName) {
    final faculty = uadData["Universitas Ahmad Dahlan"]![facultyName];
    return faculty?["kode"] ?? "";
  }

  // Get all study programs for a faculty
  static List<String> getAllStudyPrograms(String facultyName) {
    final faculty = uadData["Universitas Ahmad Dahlan"]![facultyName];
    if (faculty == null) return [];

    List<String> allPrograms = [];

    faculty.forEach((key, value) {
      if (key != "kode" && value is List) {
        allPrograms.addAll(List<String>.from(value));
      }
    });

    return allPrograms;
  }

  // Get study programs by level for a faculty
  static Map<String, List<String>> getStudyProgramsByLevel(String facultyName) {
    final faculty = uadData["Universitas Ahmad Dahlan"]![facultyName];
    if (faculty == null) return {};

    Map<String, List<String>> programsByLevel = {};

    faculty.forEach((key, value) {
      if (key != "kode" && value is List) {
        programsByLevel[key] = List<String>.from(value);
      }
    });

    return programsByLevel;
  }
}
