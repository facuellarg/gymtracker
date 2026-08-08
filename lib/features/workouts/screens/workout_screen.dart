import 'package:flutter/material.dart';
import 'package:gymtracker/features/workouts/models/rep.dart';
import 'package:gymtracker/features/workouts/models/set.dart';
import 'package:gymtracker/features/workouts/models/workouts.dart';
import 'package:gymtracker/features/workouts/widgets/Workout.dart';

class WorkoutScreen extends StatefulWidget {
  const WorkoutScreen({super.key});

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  late final Workout workout = Workout(
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

  String _titleFor(DateTime date) {
    final now = DateTime.now();
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return 'Today';
    }
    return '${date.month}/${date.day}';
  }

  Future<void> _addExercise() async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => const _AddExerciseDialog(),
    );
    final trimmed = name?.trim() ?? '';
    if (trimmed.isEmpty || !mounted) return;
    setState(() {
      workout.sets.add(ExerciseSet(exercise: trimmed, reps: []));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titleFor(workout.date)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add exercise',
            onPressed: _addExercise,
          ),
        ],
      ),
      body: WorkoutWidget(workout: workout),
    );
  }
}

class _AddExerciseDialog extends StatefulWidget {
  const _AddExerciseDialog();

  @override
  State<_AddExerciseDialog> createState() => _AddExerciseDialogState();
}

class _AddExerciseDialogState extends State<_AddExerciseDialog> {
  final _nameCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _submit() => Navigator.pop(context, _nameCtrl.text);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: const Text('Add exercise'),
      content: TextField(
        controller: _nameCtrl,
        decoration: const InputDecoration(labelText: 'exercise'),
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('cancel'),
        ),
        TextButton(onPressed: _submit, child: const Text('add')),
      ],
    );
  }
}
