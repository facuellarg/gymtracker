import 'package:flutter_test/flutter_test.dart';
import 'package:gymtracker/core/services/workout_backup.dart';
import 'package:gymtracker/core/utils/workout_labels.dart';
import 'package:gymtracker/features/workouts/models/rep.dart';
import 'package:gymtracker/features/workouts/models/set.dart';
import 'package:gymtracker/features/workouts/models/workouts.dart';

void main() {
  test('encode/decode roundtrip uses backup JSON shape', () {
    final original = [
      Workout(
        name: 'Push',
        date: DateTime(2026, 3, 12),
        sets: [
          ExerciseSet(
            exercise: 'bench',
            reps: [Rep(weight: 60, reps: 8), Rep(weight: 60, reps: 8)],
          ),
        ],
      ),
      Workout(
        name: defaultWorkoutName,
        date: DateTime(2026, 3, 10),
        sets: [],
      ),
    ];

    final json = WorkoutBackup.encode(original);
    expect(json, contains('"workoutdate": "2026-03-12"'));
    expect(json, contains('"workoutname": "Push"'));
    expect(json, contains('"rep": 8'));
    expect(json, contains('"weight": 60'));

    final decoded = WorkoutBackup.decode(json);
    expect(decoded, hasLength(2));
    expect(decoded[0].name, 'Push');
    expect(decoded[0].date, DateTime(2026, 3, 12));
    expect(decoded[0].sets.single.exercise, 'bench');
    expect(decoded[0].sets.single.reps, hasLength(2));
    expect(decoded[0].sets.single.reps[0].weight, 60);
    expect(decoded[0].sets.single.reps[0].reps, 8);
    expect(decoded[1].sets, isEmpty);
  });
}
