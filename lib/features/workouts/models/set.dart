import 'package:gymtracker/features/workouts/models/rep.dart';

class ExerciseSet {
  final int? id;
  final String exercise;
  final List<Rep> reps;

  const ExerciseSet({
    this.id,
    required this.exercise,
    required this.reps,
  });
}
