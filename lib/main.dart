import 'package:flutter/material.dart';
import 'package:gymtracker/features/workouts/models/rep.dart';
import 'package:gymtracker/features/workouts/models/set.dart';
import 'package:gymtracker/features/workouts/models/workouts.dart';
import 'package:gymtracker/features/workouts/widgets/Workout.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  static final workout = Workout(
    name: 'Today',
    date: DateTime.now(),
    sets: [
      ExerciseSet(
        exercise: 'bench',
        reps: [
          Rep(weight: 60, reps: 8),
          Rep(weight: 70, reps: 8),
          Rep(weight: 70, reps: 8),
          Rep(weight: 70, reps: 8),
        ],
      ),
      ExerciseSet(
        exercise: 'squats',
        reps: [
          Rep(weight: 100, reps: 10),
          Rep(weight: 100, reps: 10),
        ],
      ),
      ExerciseSet(
        exercise: 'deadlifts',
        reps: [
          Rep(weight: 120, reps: 5),
          Rep(weight: 130, reps: 5),
        ],
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(body: WorkoutWidget(workout: workout)),
    );
  }
}
