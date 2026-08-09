import 'package:flutter/material.dart';
import 'package:gymtracker/core/utils/workout_labels.dart';
import 'package:gymtracker/features/workouts/models/set.dart';
import 'package:gymtracker/features/workouts/models/workouts.dart';
import 'package:gymtracker/features/workouts/repository/workout_repository.dart';
import 'package:gymtracker/features/workouts/widgets/Workout.dart';
import 'package:gymtracker/l10n/app_localizations.dart';

class WorkoutScreen extends StatefulWidget {
  final WorkoutRepository repository;

  const WorkoutScreen({super.key, required this.repository});

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  Workout? _workout;
  Object? _loadError;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final existing = await widget.repository.getToday();
      if (!mounted) return;
      setState(() {
        _workout = existing ?? widget.repository.draftToday();
        _loadError = null;
        _ready = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e;
        _ready = true;
      });
    }
  }

  Future<void> _save() async {
    final w = _workout;
    if (w == null) return;
    // Rest day / draft: no DB row until there is at least one exercise.
    if (w.id == null && w.sets.isEmpty) return;
    await widget.repository.saveWorkout(w);
    if (mounted) setState(() {});
  }

  Future<void> _editWorkoutName() async {
    final l10n = AppLocalizations.of(context)!;
    final workout = _workout;
    if (workout == null) return;
    final dateLabel = workoutDateLabel(context, workout.date);
    final initial = isDefaultWorkoutName(workout.name)
        ? dateLabel
        : workout.name.trim();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => _EditWorkoutNameDialog(initialName: initial),
    );
    final trimmed = name?.trim() ?? '';
    if (trimmed.isEmpty || !mounted) return;
    final stored =
        trimmed == l10n.today ? defaultWorkoutName : trimmed;
    setState(() => workout.name = stored);
    await _save();
  }

  Future<void> _addExercise() async {
    final workout = _workout;
    if (workout == null) return;
    final suggestions = await widget.repository.distinctExerciseNames();
    if (!mounted) return;
    final name = await showDialog<String>(
      context: context,
      builder: (context) => _AddExerciseDialog(suggestions: suggestions),
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
    final l10n = AppLocalizations.of(context)!;

    if (_loadError != null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.today)),
        body: Center(child: Text(l10n.failedToLoad('$_loadError'))),
      );
    }
    if (!_ready || _workout == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final workout = _workout!;
    final dateLabel = workoutDateLabel(context, workout.date);
    final name = workout.name.trim();
    final custom = hasCustomWorkoutName(name);
    final theme = Theme.of(context).textTheme;
    final empty = workout.sets.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: custom
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
            tooltip: l10n.addExercise,
            onPressed: _addExercise,
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'rename') _editWorkoutName();
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: 'rename', child: Text(l10n.rename)),
            ],
          ),
        ],
      ),
      body: empty
          ? _EmptyWorkoutBody(
              onNameSession: _editWorkoutName,
              onAddExercise: _addExercise,
            )
          : WorkoutWidget(
              workout: workout,
              onChanged: (w) => widget.repository.saveWorkout(w),
              loadExerciseNames: widget.repository.distinctExerciseNames,
            ),
    );
  }
}

class _EmptyWorkoutBody extends StatelessWidget {
  final VoidCallback onNameSession;
  final VoidCallback onAddExercise;

  const _EmptyWorkoutBody({
    required this.onNameSession,
    required this.onAddExercise,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.noWorkoutYet,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onAddExercise,
              child: Text(l10n.addExercise),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: onNameSession,
              child: Text(l10n.nameThisSession),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddExerciseDialog extends StatefulWidget {
  final List<String> suggestions;

  const _AddExerciseDialog({required this.suggestions});

  @override
  State<_AddExerciseDialog> createState() => _AddExerciseDialogState();
}

class _AddExerciseDialogState extends State<_AddExerciseDialog> {
  TextEditingController? _fieldCtrl;

  void _submit() {
    final text = _fieldCtrl?.text ?? '';
    Navigator.pop(context, text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.addExercise),
      content: Autocomplete<String>(
        optionsBuilder: (value) {
          final q = value.text.trim().toLowerCase();
          if (q.isEmpty || widget.suggestions.isEmpty) {
            return const Iterable<String>.empty();
          }
          return widget.suggestions
              .where((s) => s.toLowerCase().contains(q))
              .take(8);
        },
        onSelected: (selection) => Navigator.pop(context, selection),
        fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
          _fieldCtrl = controller;
          return TextField(
            controller: controller,
            focusNode: focusNode,
            decoration: InputDecoration(labelText: l10n.exercise),
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            onSubmitted: (_) => _submit(),
          );
        },
        optionsMaxHeight: 200,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        TextButton(onPressed: _submit, child: Text(l10n.add)),
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
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      scrollable: true,
      title: Text(l10n.editWorkout),
      content: TextField(
        controller: _nameCtrl,
        decoration: InputDecoration(labelText: l10n.name),
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        TextButton(onPressed: _submit, child: Text(l10n.save)),
      ],
    );
  }
}
