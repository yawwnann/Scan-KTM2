class Student {
  final String nim;
  final String name;
  final String faculty;
  final String studyProgram;
  final String vehicleNumber;
  final String vehicleType;
  final String vehicleBrand;
  final DateTime scanTime;

  Student({
    required this.nim,
    required this.name,
    required this.faculty,
    required this.studyProgram,
    required this.vehicleNumber,
    required this.vehicleType,
    this.vehicleBrand = '',
    required this.scanTime,
  });

  factory Student.fromJson(Map<String, dynamic> json) {
    return Student(
      nim: json['nim'] ?? '',
      name: json['name'] ?? '',
      faculty: json['faculty'] ?? '',
      studyProgram: json['study_program'] ?? '',
      vehicleNumber: json['vehicle_number'] ?? '',
      vehicleType: json['vehicle_type'] ?? '',
      vehicleBrand: json['vehicle_brand'] ?? '',
      scanTime: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nim': nim,
      'name': name,
      'faculty': faculty,
      'study_program': studyProgram,
      'vehicle_number': vehicleNumber,
      'vehicle_type': vehicleType,
      'vehicle_brand': vehicleBrand,
      'scan_time': scanTime.toIso8601String(),
    };
  }

  // Method untuk Realtime Database
  factory Student.fromFirestore(Map<dynamic, dynamic> data) {
    return Student(
      nim: data['nim']?.toString() ?? '',
      name: data['name']?.toString() ?? '',
      faculty: data['faculty']?.toString() ?? '',
      studyProgram:
          (data['study_program'] ?? data['studyProgram'])?.toString() ?? '',
      vehicleNumber:
          (data['vehicle_number'] ?? data['vehicleNumber'])?.toString() ?? '',
      vehicleType:
          (data['vehicle_type'] ?? data['vehicleType'])?.toString() ?? '',
      vehicleBrand:
          (data['vehicle_brand'] ?? data['vehicleBrand'])?.toString() ?? '',
      scanTime: DateTime.now(),
    );
  }

  // Added for Realtime Database integration
  Map<String, dynamic> toFirestore() {
    return {
      'nim': nim,
      'name': name,
      'faculty': faculty,
      'study_program': studyProgram,
      'vehicle_number': vehicleNumber,
      'vehicle_type': vehicleType,
      'vehicle_brand': vehicleBrand,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  // CRUD Operations
  static Student create({
    required String nim,
    required String name,
    required String faculty,
    required String studyProgram,
    required String vehicleNumber,
    required String vehicleType,
    String vehicleBrand = '',
  }) {
    return Student(
      nim: nim,
      name: name,
      faculty: faculty,
      studyProgram: studyProgram,
      vehicleNumber: vehicleNumber,
      vehicleType: vehicleType,
      vehicleBrand: vehicleBrand,
      scanTime: DateTime.now(),
    );
  }

  Student copyWith({
    String? nim,
    String? name,
    String? faculty,
    String? studyProgram,
    String? vehicleNumber,
    String? vehicleType,
    DateTime? scanTime,
  }) {
    return Student(
      nim: nim ?? this.nim,
      name: name ?? this.name,
      faculty: faculty ?? this.faculty,
      studyProgram: studyProgram ?? this.studyProgram,
      vehicleNumber: vehicleNumber ?? this.vehicleNumber,
      vehicleType: vehicleType ?? this.vehicleType,
      scanTime: scanTime ?? this.scanTime,
    );
  }

  @override
  String toString() {
    return 'Student(nim: $nim, name: $name, faculty: $faculty, studyProgram: $studyProgram, vehicleNumber: $vehicleNumber, vehicleType: $vehicleType, scanTime: $scanTime)';
  }
}
