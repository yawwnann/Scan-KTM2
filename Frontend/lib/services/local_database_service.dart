import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/student.dart';
import '../models/scan_history.dart';
import '../utils/logging/logger.dart';

class LocalDatabaseService {
  static final LocalDatabaseService _instance = LocalDatabaseService._internal();
  factory LocalDatabaseService() => _instance;
  LocalDatabaseService._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'stnk_check.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        // Table: students
        await db.execute('''
          CREATE TABLE students (
            nim TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            faculty TEXT,
            study_program TEXT,
            vehicle_number TEXT,
            vehicle_type TEXT,
            vehicle_brand TEXT,
            updated_at TEXT
          )
        ''');

        // Indexes for lightning-fast queries
        await db.execute(
          'CREATE INDEX idx_students_vehicle_number ON students (vehicle_number)',
        );
        await db.execute(
          'CREATE INDEX idx_students_name ON students (name)',
        );

        // Table: scan_history
        await db.execute('''
          CREATE TABLE scan_history (
            id TEXT PRIMARY KEY,
            student_nim TEXT,
            student_name TEXT,
            faculty TEXT,
            study_program TEXT,
            vehicle_number TEXT,
            vehicle_type TEXT,
            scan_time INTEGER,
            scan_method TEXT,
            location TEXT,
            is_synced INTEGER DEFAULT 0
          )
        ''');

        // Table: sync_metadata
        await db.execute('''
          CREATE TABLE sync_metadata (
            key TEXT PRIMARY KEY,
            value TEXT
          )
        ''');

        Logger.info('SQLite local database initialized successfully');
      },
    );
  }

  // ─── STUDENT OPERATIONS ─────────────────────────────────────────────

  Future<Student?> getStudentByNIM(String nim) async {
    try {
      final db = await database;
      final cleanNim = nim.trim();
      final maps = await db.query(
        'students',
        where: 'LOWER(nim) = LOWER(?)',
        whereArgs: [cleanNim],
        limit: 1,
      );

      if (maps.isNotEmpty) {
        return _mapToStudent(maps.first);
      }
      return null;
    } catch (e) {
      Logger.error('SQLite getStudentByNIM error: $e');
      return null;
    }
  }

  Future<Student?> getStudentByVehicleNumber(String vehicleNumber) async {
    try {
      final db = await database;
      // Normalisasi spasi dan huruf kapital (e.g., "AB 1234 CD" -> "AB1234CD")
      final cleanInput = vehicleNumber.replaceAll(' ', '').toUpperCase();

      // Query fleksibel: exact match atau match tanpa spasi
      final maps = await db.rawQuery(
        '''
        SELECT * FROM students 
        WHERE REPLACE(UPPER(vehicle_number), ' ', '') = ?
        LIMIT 1
        ''',
        [cleanInput],
      );

      if (maps.isNotEmpty) {
        return _mapToStudent(maps.first);
      }
      return null;
    } catch (e) {
      Logger.error('SQLite getStudentByVehicleNumber error: $e');
      return null;
    }
  }

  Future<int> insertOrUpdateStudent(Student student) async {
    try {
      final db = await database;
      return await db.insert(
        'students',
        _studentToMap(student),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      Logger.error('SQLite insertOrUpdateStudent error: $e');
      return 0;
    }
  }

  Future<int> batchUpsertStudents(List<Student> students) async {
    if (students.isEmpty) return 0;
    try {
      final db = await database;
      final batch = db.batch();

      for (final student in students) {
        batch.insert(
          'students',
          _studentToMap(student),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      final results = await batch.commit(noResult: true);
      Logger.info('SQLite batchUpsert: ${students.length} students stored');
      return results.length;
    } catch (e) {
      Logger.error('SQLite batchUpsertStudents error: $e');
      return 0;
    }
  }

  /// Sinkronisasi penuh data mahasiswa: mengosongkan cache lama dan menggantikannya dengan data backend
  Future<int> replaceAllStudents(List<Student> students) async {
    try {
      final db = await database;
      final batch = db.batch();
      batch.delete('students');

      for (final student in students) {
        batch.insert(
          'students',
          _studentToMap(student),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      await batch.commit(noResult: true);
      Logger.info('SQLite replaceAllStudents: synced ${students.length} students');
      return students.length;
    } catch (e) {
      Logger.error('SQLite replaceAllStudents error: $e');
      return 0;
    }
  }

  /// Menghapus seluruh cache mahasiswa di SQLite lokal
  Future<void> clearStudents() async {
    try {
      final db = await database;
      await db.delete('students');
      Logger.info('SQLite clearStudents: all students removed');
    } catch (e) {
      Logger.error('SQLite clearStudents error: $e');
    }
  }

  Future<List<Student>> getAllStudents({int limit = 50, int offset = 0}) async {
    try {
      final db = await database;
      final maps = await db.query(
        'students',
        orderBy: 'name ASC',
        limit: limit,
        offset: offset,
      );

      return maps.map(_mapToStudent).toList();
    } catch (e) {
      Logger.error('SQLite getAllStudents error: $e');
      return [];
    }
  }

  Future<List<Student>> searchStudents(String query, {int limit = 50}) async {
    if (query.trim().isEmpty) return getAllStudents(limit: limit);
    try {
      final db = await database;
      final q = '%${query.trim()}%';

      final maps = await db.rawQuery(
        '''
        SELECT * FROM students 
        WHERE name LIKE ? OR nim LIKE ? OR vehicle_number LIKE ?
        ORDER BY name ASC
        LIMIT ?
        ''',
        [q, q, q, limit],
      );

      return maps.map(_mapToStudent).toList();
    } catch (e) {
      Logger.error('SQLite searchStudents error: $e');
      return [];
    }
  }

  Future<int> deleteStudent(String nim) async {
    try {
      final db = await database;
      return await db.delete(
        'students',
        where: 'nim = ?',
        whereArgs: [nim.trim()],
      );
    } catch (e) {
      Logger.error('SQLite deleteStudent error: $e');
      return 0;
    }
  }

  Future<int> getStudentCount() async {
    try {
      final db = await database;
      final result = await db.rawQuery('SELECT COUNT(*) as count FROM students');
      return Sqflite.firstIntValue(result) ?? 0;
    } catch (e) {
      Logger.error('SQLite getStudentCount error: $e');
      return 0;
    }
  }

  // ─── SCAN HISTORY OPERATIONS ────────────────────────────────────────

  Future<int> insertScanHistory(
    ScanHistory history, {
    bool isSynced = false,
  }) async {
    try {
      final db = await database;
      return await db.insert(
        'scan_history',
        {
          'id': history.id,
          'student_nim': history.studentNim,
          'student_name': history.studentName,
          'faculty': history.faculty,
          'study_program': history.studyProgram,
          'vehicle_number': history.vehicleNumber,
          'vehicle_type': history.vehicleType,
          'scan_time': history.scanTime.millisecondsSinceEpoch,
          'scan_method': history.scanMethod,
          'location': history.location,
          'is_synced': isSynced ? 1 : 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      Logger.error('SQLite insertScanHistory error: $e');
      return 0;
    }
  }

  Future<List<ScanHistory>> getUnsyncedScanHistories() async {
    try {
      final db = await database;
      final maps = await db.query(
        'scan_history',
        where: 'is_synced = 0',
        orderBy: 'scan_time ASC',
      );

      return maps.map(_mapToScanHistory).toList();
    } catch (e) {
      Logger.error('SQLite getUnsyncedScanHistories error: $e');
      return [];
    }
  }

  Future<void> markScanHistoriesAsSynced(List<String> ids) async {
    if (ids.isEmpty) return;
    try {
      final db = await database;
      final batch = db.batch();
      for (final id in ids) {
        batch.update(
          'scan_history',
          {'is_synced': 1},
          where: 'id = ?',
          whereArgs: [id],
        );
      }
      await batch.commit(noResult: true);
    } catch (e) {
      Logger.error('SQLite markScanHistoriesAsSynced error: $e');
    }
  }

  Future<List<ScanHistory>> getAllScanHistories({int limit = 100}) async {
    try {
      final db = await database;
      final maps = await db.query(
        'scan_history',
        orderBy: 'scan_time DESC',
        limit: limit,
      );

      return maps.map(_mapToScanHistory).toList();
    } catch (e) {
      Logger.error('SQLite getAllScanHistories error: $e');
      return [];
    }
  }

  Future<void> clearScanHistory() async {
    try {
      final db = await database;
      await db.delete('scan_history');
    } catch (e) {
      Logger.error('SQLite clearScanHistory error: $e');
    }
  }

  // ─── METADATA OPERATIONS ────────────────────────────────────────────

  Future<void> setMetadata(String key, String value) async {
    try {
      final db = await database;
      await db.insert(
        'sync_metadata',
        {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      Logger.error('SQLite setMetadata error: $e');
    }
  }

  Future<String?> getMetadata(String key) async {
    try {
      final db = await database;
      final maps = await db.query(
        'sync_metadata',
        where: 'key = ?',
        whereArgs: [key],
        limit: 1,
      );
      if (maps.isNotEmpty) {
        return maps.first['value'] as String?;
      }
      return null;
    } catch (e) {
      Logger.error('SQLite getMetadata error: $e');
      return null;
    }
  }

  Future<void> clearAll() async {
    try {
      final db = await database;
      await db.delete('students');
      await db.delete('scan_history');
      await db.delete('sync_metadata');
    } catch (e) {
      Logger.error('SQLite clearAll error: $e');
    }
  }

  // ─── HELPERS ────────────────────────────────────────────────────────

  Map<String, dynamic> _studentToMap(Student student) {
    return {
      'nim': student.nim,
      'name': student.name,
      'faculty': student.faculty,
      'study_program': student.studyProgram,
      'vehicle_number': student.vehicleNumber,
      'vehicle_type': student.vehicleType,
      'vehicle_brand': student.vehicleBrand,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  Student _mapToStudent(Map<String, dynamic> map) {
    return Student(
      nim: map['nim'] as String? ?? '',
      name: map['name'] as String? ?? '',
      faculty: map['faculty'] as String? ?? '',
      studyProgram: map['study_program'] as String? ?? '',
      vehicleNumber: map['vehicle_number'] as String? ?? '',
      vehicleType: map['vehicle_type'] as String? ?? '',
      vehicleBrand: map['vehicle_brand'] as String? ?? '',
      scanTime: DateTime.now(),
    );
  }

  ScanHistory _mapToScanHistory(Map<String, dynamic> map) {
    return ScanHistory(
      id: map['id'] as String? ?? '',
      studentNim: map['student_nim'] as String? ?? '',
      studentName: map['student_name'] as String? ?? '',
      faculty: map['faculty'] as String? ?? '',
      studyProgram: map['study_program'] as String? ?? '',
      vehicleNumber: map['vehicle_number'] as String? ?? '',
      vehicleType: map['vehicle_type'] as String? ?? '',
      scanTime: DateTime.fromMillisecondsSinceEpoch(
        map['scan_time'] as int? ?? 0,
      ),
      scanMethod: map['scan_method'] as String? ?? 'unknown',
      location: map['location'] as String? ?? 'Campus Gate',
    );
  }
}
