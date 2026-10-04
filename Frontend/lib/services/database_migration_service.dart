import 'package:firebase_database/firebase_database.dart';
import '../utils/logging/logger.dart';

class DatabaseMigrationService {
  static Future<void> migrateToSnakeCase() async {
    try {
      Logger.info('Starting Database Migration to snake_case...');
      final database = FirebaseDatabase.instance.ref();
      final snapshot = await database.child('students').get();

      if (!snapshot.exists || snapshot.value == null) {
        Logger.info('No students found to migrate.');
        return;
      }

      final students = snapshot.value as Map<dynamic, dynamic>;
      int migratedCount = 0;

      for (var entry in students.entries) {
        final key = entry.key.toString();
        final data = entry.value as Map<dynamic, dynamic>;
        bool needsUpdate = false;
        final updates = <String, dynamic>{};

        // Check studyProgram
        if (data.containsKey('studyProgram')) {
          updates['study_program'] = data['studyProgram'];
          updates['studyProgram'] = null; // Delete old key
          needsUpdate = true;
        }

        // Check vehicleNumber
        if (data.containsKey('vehicleNumber')) {
          updates['vehicle_number'] = data['vehicleNumber'];
          updates['vehicleNumber'] = null; // Delete old key
          needsUpdate = true;
        }

        // Check vehicleType
        if (data.containsKey('vehicleType')) {
          updates['vehicle_type'] = data['vehicleType'];
          updates['vehicleType'] = null; // Delete old key
          needsUpdate = true;
        }

        if (needsUpdate) {
          await database.child('students/$key').update(updates);
          migratedCount++;
        }
      }

      Logger.info(
        'Migration completed successfully. Updated $migratedCount records.',
      );
    } catch (e) {
      Logger.error('Migration failed: $e');
    }
  }
}
