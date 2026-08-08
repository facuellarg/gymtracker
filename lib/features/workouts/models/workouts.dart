import 'package:gymtracker/features/workouts/models/set.dart';

class Workout {
  final String name;
  final List<ExerciseSet> sets;
  final DateTime date;

  const Workout({required this.name, required this.sets, required this.date});
}
