import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:gymtracker/core/database/migrations.dart';

class AppDatabase {
  AppDatabase._(this.db);

  final Database db;

  static Future<AppDatabase> open() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'gymtracker.db');
    final database = await openDatabase(
      path,
      version: workoutDbVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: onCreate,
    );
    return AppDatabase._(database);
  }
}
