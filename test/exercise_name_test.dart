import 'package:flutter_test/flutter_test.dart';
import 'package:gymtracker/core/utils/exercise_name.dart';

void main() {
  test('normalizeExerciseKey trims and lowercases', () {
    expect(normalizeExerciseKey('  Bench Press  '), 'bench press');
    expect(normalizeExerciseKey('BENCH'), 'bench');
    expect(normalizeExerciseKey('bench'), 'bench');
    expect(normalizeExerciseKey(''), '');
  });

  test('matchExerciseName prefers exact, then prefix, then contains', () {
    final names = [
      (exercise: 'jalon de pecho'),
      (exercise: 'pecho plano'),
      (exercise: 'pecho'),
      (exercise: 'ohp'),
    ];
    expect(matchExerciseName(names, 'pecho'), 'pecho');
    expect(matchExerciseName(names, 'pecho p'), 'pecho plano');
    expect(matchExerciseName(names, 'jalon'), 'jalon de pecho');
    expect(matchExerciseName(names, 'deadlift'), isNull);
  });

  test('exerciseNameSuggestions ranks prefix before contains', () {
    final catalog = ['jalon de pecho', 'pecho', 'pecho plano', 'press'];
    expect(
      exerciseNameSuggestions(catalog, 'pecho').toList(),
      ['pecho', 'pecho plano', 'jalon de pecho'],
    );
    expect(exerciseNameSuggestions(catalog, 'press').toList(), ['press']);
    expect(exerciseNameSuggestions(catalog, '').toList(), isEmpty);
  });

  test('formatRepsPreview joins sets', () {
    expect(
      formatRepsPreview([
        (weight: 60, reps: 8),
        (weight: 70, reps: 5),
      ]),
      '60*8 | 70*5',
    );
  });
}
