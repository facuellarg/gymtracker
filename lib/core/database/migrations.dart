import 'package:sqflite/sqflite.dart';

const workoutDbVersion = 1;

Future<void> onCreate(Database db, int version) async {
  await db.execute('''
    CREATE TABLE workouts (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      date TEXT NOT NULL UNIQUE
    )
  ''');
  await db.execute('''
    CREATE TABLE exercise_sets (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      workout_id INTEGER NOT NULL,
      exercise TEXT NOT NULL,
      sort_order INTEGER NOT NULL,
      FOREIGN KEY (workout_id) REFERENCES workouts (id) ON DELETE CASCADE
    )
  ''');
  await db.execute('''
    CREATE TABLE reps (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      exercise_set_id INTEGER NOT NULL,
      weight INTEGER NOT NULL,
      reps INTEGER NOT NULL,
      sort_order INTEGER NOT NULL,
      FOREIGN KEY (exercise_set_id) REFERENCES exercise_sets (id) ON DELETE CASCADE
    )
  ''');
  await seedHistorySamples(db);
}

/// Demo history rows — only called on first DB create.
Future<void> seedHistorySamples(Database db) async {
  final now = DateTime.now();
  final pullDate = now.subtract(const Duration(days: 2));
  final pushDate = now.subtract(const Duration(days: 5));

  await _insertSeedWorkout(
    db,
    name: 'Pull',
    date: _dateKey(pullDate),
    sets: [
      (
        'deadlifts',
        [(120, 5), (130, 5)],
      ),
      (
        'rows',
        [(60, 10)],
      ),
    ],
  );
  await _insertSeedWorkout(
    db,
    name: 'Push',
    date: _dateKey(pushDate),
    sets: [
      (
        'bench',
        [(65, 8)],
      ),
      (
        'ohp',
        [(40, 8)],
      ),
    ],
  );
}

String _dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

Future<void> _insertSeedWorkout(
  Database db, {
  required String name,
  required String date,
  required List<(String exercise, List<(int weight, int reps)> reps)> sets,
}) async {
  final workoutId = await db.insert('workouts', {'name': name, 'date': date});
  for (var si = 0; si < sets.length; si++) {
    final (exercise, reps) = sets[si];
    final setId = await db.insert('exercise_sets', {
      'workout_id': workoutId,
      'exercise': exercise,
      'sort_order': si,
    });
    for (var ri = 0; ri < reps.length; ri++) {
      final (weight, count) = reps[ri];
      await db.insert('reps', {
        'exercise_set_id': setId,
        'weight': weight,
        'reps': count,
        'sort_order': ri,
      });
    }
  }
}
