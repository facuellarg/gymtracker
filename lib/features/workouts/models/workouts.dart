import 'package:gymtracker/features/workouts/models/set.dart';

class Workout {
  String name;
  final List<ExerciseSet> sets;
  final DateTime date;

  Workout({required this.name, required this.sets, required this.date});
}
