import 'package:sqflite/sqflite.dart';
import 'package:gymtracker/core/database/app_database.dart';
import 'package:gymtracker/core/utils/exercise_name.dart';
import 'package:gymtracker/core/utils/workout_labels.dart';
import 'package:gymtracker/features/workouts/models/rep.dart';
import 'package:gymtracker/features/workouts/models/set.dart';
import 'package:gymtracker/features/workouts/models/workouts.dart';

class WorkoutRepository {
  WorkoutRepository(this._db);

  final AppDatabase _db;

  Database get db => _db.db;

  static String dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static DateTime parseDateKey(String key) {
    final parts = key.split('-');
    return DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }

  /// Today's session if one exists; does not insert.
  Future<Workout?> getToday() async {
    await pruneEmptyDefaultWorkouts();
    final key = dateKey(DateTime.now());
    final existing = await db.query(
      'workouts',
      where: 'date = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (existing.isEmpty) return null;
    return _loadWorkout(existing.first);
  }

  /// In-memory draft — persisted only on [saveWorkout].
  Workout draftToday() {
    final today = DateTime.now();
    return Workout(
      name: defaultWorkoutName,
      date: DateTime(today.year, today.month, today.day),
      sets: [],
    );
  }

  /// Ghost cleanup: today's untitled sessions with no exercises only.
  Future<void> pruneEmptyDefaultWorkouts() async {
    final today = dateKey(DateTime.now());
    await db.rawDelete(
      'DELETE FROM workouts WHERE name = ? AND date = ? AND id NOT IN '
      '(SELECT DISTINCT workout_id FROM exercise_sets)',
      [defaultWorkoutName, today],
    );
  }

  /// Session for [date] if any.
  Future<Workout?> getByDate(DateTime date) async {
    final key = dateKey(date);
    final existing = await db.query(
      'workouts',
      where: 'date = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (existing.isEmpty) return null;
    return _loadWorkout(existing.first);
  }

  /// Load or create an untitled session for [date] (date-only, no time).
  Future<Workout> getOrCreateForDate(DateTime date) async {
    final d = DateTime(date.year, date.month, date.day);
    final existing = await getByDate(d);
    if (existing != null) return existing;
    final id = await db.insert('workouts', {
      'name': defaultWorkoutName,
      'date': dateKey(d),
    });
    return Workout(id: id, name: defaultWorkoutName, date: d, sets: []);
  }

  Future<List<Workout>> getAll() async {
    final rows = await db.query('workouts', orderBy: 'date DESC');
    final out = <Workout>[];
    for (final row in rows) {
      out.add(await _loadWorkout(row));
    }
    return out;
  }

  Future<Workout?> getById(int id) async {
    final rows = await db.query(
      'workouts',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _loadWorkout(rows.first);
  }

  Future<void> deleteWorkout(int id) async {
    await db.delete('workouts', where: 'id = ?', whereArgs: [id]);
  }

  /// Distinct exercise names the user has logged (for autocomplete).
  Future<List<String>> distinctExerciseNames() async {
    final rows = await db.rawQuery(
      'SELECT DISTINCT exercise FROM exercise_sets '
      'ORDER BY exercise COLLATE NOCASE ASC',
    );
    return [for (final r in rows) (r['exercise'] as String).trim()];
  }

  /// Most recent prior session's sets for [exercise] (trim + case-insensitive).
  Future<List<Rep>> lastRepsForExercise(
    String exercise, {
    int? excludeWorkoutId,
  }) async {
    final key = normalizeExerciseKey(exercise);
    if (key.isEmpty) return const [];

    final rows = await db.rawQuery(
      'SELECT es.id AS set_id FROM exercise_sets es '
      'INNER JOIN workouts w ON w.id = es.workout_id '
      'WHERE LOWER(TRIM(es.exercise)) = ? '
      'AND (? IS NULL OR w.id != ?) '
      'ORDER BY w.date DESC, es.id DESC '
      'LIMIT 1',
      [key, excludeWorkoutId, excludeWorkoutId],
    );
    if (rows.isEmpty) return const [];

    final setId = rows.first['set_id'] as int;
    final repRows = await db.query(
      'reps',
      where: 'exercise_set_id = ?',
      whereArgs: [setId],
      orderBy: 'sort_order ASC',
    );
    return [
      for (final r in repRows)
        Rep(weight: r['weight'] as int, reps: r['reps'] as int),
    ];
  }

  /// Upsert workout row; replace all exercise_sets/reps for that workout.
  Future<void> saveWorkout(Workout w) async {
    await db.transaction((txn) async {
      final key = dateKey(w.date);
      int workoutId;
      if (w.id != null) {
        await txn.update(
          'workouts',
          {'name': w.name, 'date': key},
          where: 'id = ?',
          whereArgs: [w.id],
        );
        workoutId = w.id!;
      } else {
        final existing = await txn.query(
          'workouts',
          columns: ['id'],
          where: 'date = ?',
          whereArgs: [key],
          limit: 1,
        );
        if (existing.isNotEmpty) {
          workoutId = existing.first['id'] as int;
          await txn.update(
            'workouts',
            {'name': w.name, 'date': key},
            where: 'id = ?',
            whereArgs: [workoutId],
          );
          w.id = workoutId;
        } else {
          workoutId = await txn.insert('workouts', {
            'name': w.name,
            'date': key,
          });
          w.id = workoutId;
        }
      }

      final oldSets = await txn.query(
        'exercise_sets',
        columns: ['id'],
        where: 'workout_id = ?',
        whereArgs: [workoutId],
      );
      for (final s in oldSets) {
        await txn.delete(
          'reps',
          where: 'exercise_set_id = ?',
          whereArgs: [s['id']],
        );
      }
      await txn.delete(
        'exercise_sets',
        where: 'workout_id = ?',
        whereArgs: [workoutId],
      );

      for (var si = 0; si < w.sets.length; si++) {
        final set = w.sets[si];
        final setId = await txn.insert('exercise_sets', {
          'workout_id': workoutId,
          'exercise': set.exercise.trim(),
          'sort_order': si,
        });
        for (var ri = 0; ri < set.reps.length; ri++) {
          final rep = set.reps[ri];
          await txn.insert('reps', {
            'exercise_set_id': setId,
            'weight': rep.weight,
            'reps': rep.reps,
            'sort_order': ri,
          });
        }
      }
    });
  }

  Future<Workout> _loadWorkout(Map<String, Object?> row) async {
    final workoutId = row['id'] as int;
    final setRows = await db.query(
      'exercise_sets',
      where: 'workout_id = ?',
      whereArgs: [workoutId],
      orderBy: 'sort_order ASC',
    );
    final sets = <ExerciseSet>[];
    for (final s in setRows) {
      final setId = s['id'] as int;
      final repRows = await db.query(
        'reps',
        where: 'exercise_set_id = ?',
        whereArgs: [setId],
        orderBy: 'sort_order ASC',
      );
      sets.add(
        ExerciseSet(
          id: setId,
          exercise: s['exercise'] as String,
          reps: [
            for (final r in repRows)
              Rep(
                id: r['id'] as int,
                weight: r['weight'] as int,
                reps: r['reps'] as int,
              ),
          ],
        ),
      );
    }
    return Workout(
      id: workoutId,
      name: row['name'] as String,
      date: parseDateKey(row['date'] as String),
      sets: sets,
    );
  }
}
