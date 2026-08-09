import 'package:flutter_test/flutter_test.dart';
import 'package:gymtracker/core/utils/workout_labels.dart';
import 'package:gymtracker/features/workouts/models/workouts.dart';

/// Mirrors Log persist rule: drafts without exercises stay out of the DB.
bool shouldPersistWorkout(Workout w) =>
    w.id != null || w.sets.isNotEmpty;

void main() {
  test('empty draft is not persisted', () {
    final draft = Workout(
      name: defaultWorkoutName,
      date: DateTime(2026, 8, 8),
      sets: [],
    );
    expect(shouldPersistWorkout(draft), isFalse);
  });

  test('existing or non-empty workout is persisted', () {
    expect(
      shouldPersistWorkout(
        Workout(
          id: 1,
          name: defaultWorkoutName,
          date: DateTime(2026, 8, 8),
          sets: [],
        ),
      ),
      isTrue,
    );
  });
}
