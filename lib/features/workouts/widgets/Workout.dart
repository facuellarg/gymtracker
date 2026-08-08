import 'package:flutter/material.dart';
import 'package:gymtracker/features/workouts/models/workouts.dart';

class WorkoutWidget extends StatelessWidget {
  final Workout workout;

  const WorkoutWidget({super.key, required this.workout});

  @override
  Widget build(BuildContext context) {
    final colCount = workout.sets.fold<int>(
      0,
      (max, set) => set.reps.length > max ? set.reps.length : max,
    );

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: workout.sets.length + 1,
      itemBuilder: (context, i) {
        final header = i == 0;
        final style =
            header ? const TextStyle(fontWeight: FontWeight.bold) : null;
        final name = header ? 'name' : workout.sets[i - 1].exercise;
        final cells = [
          for (var c = 0; c < colCount; c++)
            header
                ? 'w/rep'
                : c < workout.sets[i - 1].reps.length
                    ? '${workout.sets[i - 1].reps[c].weight}'
                        '*${workout.sets[i - 1].reps[c].reps}'
                    : '',
        ];

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Expanded(flex: 2, child: Text(name, style: style)),
              for (final cell in cells)
                Expanded(child: Text(cell, style: style)),
            ],
          ),
        );
      },
    );
  }
}
