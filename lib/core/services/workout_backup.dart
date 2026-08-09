import 'dart:convert';

import 'package:gymtracker/core/utils/workout_labels.dart';
import 'package:gymtracker/features/workouts/models/rep.dart';
import 'package:gymtracker/features/workouts/models/set.dart';
import 'package:gymtracker/features/workouts/models/workouts.dart';
import 'package:gymtracker/features/workouts/repository/workout_repository.dart';

/// JSON backup shape:
/// `[{ workoutdate, workoutname, exercises: [{ name, set: [{ rep, weight }] }] }]`
class WorkoutBackup {
  static String encode(List<Workout> workouts) {
    final list = [
      for (final w in workouts)
        {
          'workoutdate': WorkoutRepository.dateKey(w.date),
          'workoutname': w.name,
          'exercises': [
            for (final s in w.sets)
              {
                'name': s.exercise,
                'set': [
                  for (final r in s.reps)
                    {'rep': r.reps, 'weight': r.weight},
                ],
              },
          ],
        },
    ];
    return const JsonEncoder.withIndent('  ').convert(list);
  }

  static List<Workout> decode(String json) {
    final raw = jsonDecode(json);
    if (raw is! List) {
      throw const FormatException('Backup root must be a JSON array');
    }
    return [for (final item in raw) _workoutFromJson(item)];
  }

  static Workout _workoutFromJson(Object? item) {
    if (item is! Map) {
      throw const FormatException('Each workout must be a JSON object');
    }
    final map = Map<String, dynamic>.from(item);
    final dateRaw = map['workoutdate']?.toString().trim() ?? '';
    if (dateRaw.isEmpty) {
      throw const FormatException('Missing workoutdate');
    }
    final name = (map['workoutname']?.toString() ?? '').trim();
    final exercisesRaw = map['exercises'];
    final sets = <ExerciseSet>[];
    if (exercisesRaw is List) {
      for (final ex in exercisesRaw) {
        if (ex is! Map) continue;
        final exMap = Map<String, dynamic>.from(ex);
        final exName = (exMap['name']?.toString() ?? '').trim();
        if (exName.isEmpty) continue;
        final reps = <Rep>[];
        final setRaw = exMap['set'];
        if (setRaw is List) {
          for (final row in setRaw) {
            if (row is! Map) continue;
            final rowMap = Map<String, dynamic>.from(row);
            reps.add(
              Rep(
                weight: _asInt(rowMap['weight']),
                reps: _asInt(rowMap['rep']),
              ),
            );
          }
        }
        sets.add(ExerciseSet(exercise: exName, reps: reps));
      }
    }
    return Workout(
      name: name.isEmpty ? defaultWorkoutName : name,
      date: WorkoutRepository.parseDateKey(dateRaw),
      sets: sets,
    );
  }

  static int _asInt(Object? v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v.trim()) ?? 0;
    return 0;
  }
}
