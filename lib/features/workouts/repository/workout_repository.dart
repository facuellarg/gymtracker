import 'package:sqflite/sqflite.dart';
import 'package:gymtracker/core/database/app_database.dart';
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

  Future<Workout> getOrCreateToday() async {
    final today = DateTime.now();
    final key = dateKey(today);
    final existing = await db.query(
      'workouts',
      where: 'date = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      return _loadWorkout(existing.first);
    }
    final id = await db.insert('workouts', {
      'name': 'Today',
      'date': key,
    });
    return Workout(id: id, name: 'Today', date: today, sets: []);
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
          'exercise': set.exercise,
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
