import 'package:flutter_test/flutter_test.dart';
import 'package:gymtracker/core/utils/exercise_name.dart';

void main() {
  test('normalizeExerciseKey trims and lowercases', () {
    expect(normalizeExerciseKey('  Bench Press  '), 'bench press');
    expect(normalizeExerciseKey('BENCH'), 'bench');
    expect(normalizeExerciseKey('bench'), 'bench');
    expect(normalizeExerciseKey(''), '');
  });
}
