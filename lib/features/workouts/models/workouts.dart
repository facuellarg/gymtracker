import 'package:gymtracker/features/workouts/models/set.dart';

class Workout {
  int? id;
  String name;
  final List<ExerciseSet> sets;
  final DateTime date;

  Workout({
    this.id,
    required this.name,
    required this.sets,
    required this.date,
  });
}
