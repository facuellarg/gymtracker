import 'package:gymtracker/features/workouts/models/rep.dart';

class ExerciseSet {
  final String exercise;
  final List<Rep> reps;

  const ExerciseSet({required this.exercise, required this.reps});
}
