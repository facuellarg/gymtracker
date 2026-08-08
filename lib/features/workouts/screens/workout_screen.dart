import 'package:flutter/material.dart';
import 'package:gymtracker/features/workouts/models/set.dart';
import 'package:gymtracker/features/workouts/models/workouts.dart';
import 'package:gymtracker/features/workouts/repository/workout_repository.dart';
import 'package:gymtracker/features/workouts/widgets/Workout.dart';

class WorkoutScreen extends StatefulWidget {
  final WorkoutRepository repository;

  const WorkoutScreen({super.key, required this.repository});

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  Workout? _workout;
  Object? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final w = await widget.repository.getOrCreateToday();
      if (!mounted) return;
      setState(() {
        _workout = w;
        _loadError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadError = e);
    }
  }

  Future<void> _save() async {
    final w = _workout;
    if (w == null) return;
    await widget.repository.saveWorkout(w);
  }

  String _titleFor(DateTime date) {
    final now = DateTime.now();
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return 'Today';
    }
    return '${date.month}/${date.day}';
  }

  Future<void> _editWorkoutName() async {
    final workout = _workout;
    if (workout == null) return;
    final dateLabel = _titleFor(workout.date);
    final initial =
        workout.name.trim().isEmpty ? dateLabel : workout.name.trim();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => _EditWorkoutNameDialog(initialName: initial),
    );
    final trimmed = name?.trim() ?? '';
    if (trimmed.isEmpty || !mounted) return;
    setState(() => workout.name = trimmed);
    await _save();
  }

  Future<void> _addExercise() async {
    final workout = _workout;
    if (workout == null) return;
    final name = await showDialog<String>(
      context: context,
      builder: (context) => const _AddExerciseDialog(),
    );
    final trimmed = name?.trim() ?? '';
    if (trimmed.isEmpty || !mounted) return;
    setState(() {
      workout.sets.add(ExerciseSet(exercise: trimmed, reps: []));
    });
    await _save();
  }

  @override
  Widget build(BuildContext context) {
    if (_loadError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Today')),
        body: Center(child: Text('Failed to load: $_loadError')),
      );
    }
    final workout = _workout;
    if (workout == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final dateLabel = _titleFor(workout.date);
    final name = workout.name.trim();
    final hasCustomName = name.isNotEmpty && name != dateLabel;
    final theme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: hasCustomName
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: theme.titleLarge),
                  Text(dateLabel, style: theme.labelMedium),
                ],
              )
            : Text(dateLabel),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add exercise',
            onPressed: _addExercise,
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'rename') _editWorkoutName();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'rename', child: Text('Rename')),
            ],
          ),
        ],
      ),
      body: WorkoutWidget(
        workout: workout,
        onChanged: (w) => widget.repository.saveWorkout(w),
      ),
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

class _EditWorkoutNameDialog extends StatefulWidget {
  final String initialName;

  const _EditWorkoutNameDialog({required this.initialName});

  @override
  State<_EditWorkoutNameDialog> createState() => _EditWorkoutNameDialogState();
}

class _EditWorkoutNameDialogState extends State<_EditWorkoutNameDialog> {
  late final _nameCtrl = TextEditingController(text: widget.initialName);

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
      title: const Text('Edit workout'),
      content: TextField(
        controller: _nameCtrl,
        decoration: const InputDecoration(labelText: 'name'),
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('cancel'),
        ),
        TextButton(onPressed: _submit, child: const Text('save')),
      ],
    );
  }
}
