import 'package:flutter/material.dart';
import 'package:gymtracker/core/utils/exercise_name.dart';
import 'package:gymtracker/core/utils/workout_labels.dart';
import 'package:gymtracker/features/workouts/models/set.dart';
import 'package:gymtracker/features/workouts/models/workouts.dart';
import 'package:gymtracker/features/workouts/repository/workout_repository.dart';
import 'package:gymtracker/features/workouts/widgets/Workout.dart';
import 'package:gymtracker/l10n/app_localizations.dart';

class HistoryScreen extends StatefulWidget {
  final WorkoutRepository repository;
  final VoidCallback onOpenToday;
  final VoidCallback onOpenSettings;
  final VoidCallback onTodayChanged;

  const HistoryScreen({
    super.key,
    required this.repository,
    required this.onOpenToday,
    required this.onOpenSettings,
    required this.onTodayChanged,
  });

  @override
  State<HistoryScreen> createState() => HistoryScreenState();
}

class HistoryScreenState extends State<HistoryScreen> {
  final _query = TextEditingController();
  List<Workout> _sessions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    reload();
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> reload() async {
    setState(() => _loading = true);
    final list = await widget.repository.getAll();
    if (!mounted) return;
    setState(() {
      _sessions = list;
      _loading = false;
    });
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  String _preview(Workout w) => w.sets.map((s) => s.exercise).join(', ');

  List<Workout> get _filtered {
    final q = _query.text.trim().toLowerCase();
    final list = [..._sessions]..sort((a, b) => b.date.compareTo(a.date));
    if (q.isEmpty) return list;
    return list
        .where(
          (w) =>
              w.name.toLowerCase().contains(q) ||
              w.sets.any((s) => s.exercise.toLowerCase().contains(q)),
        )
        .toList();
  }

  void _openSession(Workout workout, {bool startEditing = false}) {
    if (_isToday(workout.date)) {
      widget.onOpenToday();
      return;
    }

    Navigator.of(context)
        .push(
          MaterialPageRoute<void>(
            builder: (context) => _HistoryDetailPage(
              workout: workout,
              repository: widget.repository,
              dateLabel: workoutDateLabel(
                context,
                workout.date,
                withYear: true,
              ),
              startEditing: startEditing,
            ),
          ),
        )
        .then((_) {
          if (mounted) reload();
        });
  }

  Future<void> _addPastWorkout() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: today.subtract(const Duration(days: 1)),
      firstDate: DateTime(today.year - 10),
      lastDate: today,
    );
    if (picked == null || !mounted) return;

    if (_isToday(picked)) {
      widget.onOpenToday();
      return;
    }

    final workout = await widget.repository.getOrCreateForDate(picked);
    if (!mounted) return;
    _openSession(workout, startEditing: true);
  }

  Future<void> _deleteWorkout(Workout workout) async {
    final id = workout.id;
    if (id == null) return;

    final dateLabel = workoutDateLabel(context, workout.date, withYear: true);
    final name = workout.name.trim();
    final subtitle = hasCustomWorkoutName(name) ? name : dateLabel;

    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: Text(l10n.deleteWorkout),
                subtitle: Text(subtitle),
                onTap: () => Navigator.pop(context, 'delete'),
              ),
            ],
          ),
        );
      },
    );
    if (action != 'delete' || !mounted) return;

    final wasToday = _isToday(workout.date);
    await widget.repository.deleteWorkout(id);
    if (!mounted) return;

    setState(() => _sessions.removeWhere((w) => w.id == id));
    workout.id = null;
    if (wasToday) widget.onTodayChanged();

    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.workoutDeleted),
        duration: const Duration(seconds: 4),
        persist: false,
        action: SnackBarAction(
          label: l10n.undo,
          onPressed: () async {
            await widget.repository.saveWorkout(workout);
            if (!mounted) return;
            await reload();
            if (wasToday) widget.onTodayChanged();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final sessions = _filtered;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.history),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: l10n.addPastWorkout,
            onPressed: _addPastWorkout,
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: l10n.settings,
            onPressed: widget.onOpenSettings,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _query,
              decoration: InputDecoration(
                hintText: l10n.searchHint,
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : sessions.isEmpty
                    ? Center(child: Text(l10n.noSessions))
                    : ListView.separated(
                        itemCount: sessions.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final w = sessions[i];
                          final dateLabel = workoutDateLabel(
                            context,
                            w.date,
                            withYear: true,
                          );
                          final name = w.name.trim();
                          final custom = hasCustomWorkoutName(name);
                          final textTheme = Theme.of(context).textTheme;
                          final isToday = _isToday(w.date);

                          return ListTile(
                            title: custom
                                ? Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: textTheme.titleMedium,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        dateLabel,
                                        style: textTheme.labelMedium,
                                      ),
                                    ],
                                  )
                                : Text(
                                    dateLabel,
                                    style: textTheme.titleMedium,
                                  ),
                            subtitle: Text(
                              isToday ? l10n.continueInLog : _preview(w),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: isToday
                                ? const Icon(Icons.edit_note)
                                : null,
                            onTap: () => _openSession(w),
                            onLongPress: () => _deleteWorkout(w),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _HistoryDetailPage extends StatefulWidget {
  final Workout workout;
  final WorkoutRepository repository;
  final String dateLabel;
  final bool startEditing;

  const _HistoryDetailPage({
    required this.workout,
    required this.repository,
    required this.dateLabel,
    this.startEditing = false,
  });

  @override
  State<_HistoryDetailPage> createState() => _HistoryDetailPageState();
}

class _HistoryDetailPageState extends State<_HistoryDetailPage> {
  late bool _editing = widget.startEditing;

  Future<void> _rename() async {
    final l10n = AppLocalizations.of(context)!;
    final workout = widget.workout;
    final dateLabel = widget.dateLabel;
    final initial = isDefaultWorkoutName(workout.name)
        ? dateLabel
        : workout.name.trim();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => _RenameWorkoutDialog(initialName: initial),
    );
    final trimmed = name?.trim() ?? '';
    if (trimmed.isEmpty || !mounted) return;
    final stored =
        trimmed == l10n.today ? defaultWorkoutName : trimmed;
    setState(() => workout.name = stored);
    await widget.repository.saveWorkout(workout);
  }

  Future<void> _addExercise() async {
    final workout = widget.workout;
    final suggestions = await widget.repository.distinctExerciseNames();
    if (!mounted) return;
    final name = await showDialog<String>(
      context: context,
      builder: (context) => _AddExerciseDialog(suggestions: suggestions),
    );
    final trimmed = name?.trim() ?? '';
    if (trimmed.isEmpty || !mounted) return;
    setState(() {
      _editing = true;
      workout.sets.add(ExerciseSet(exercise: trimmed, reps: []));
    });
    await widget.repository.saveWorkout(workout);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final workout = widget.workout;
    final dateLabel = widget.dateLabel;
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
          if (_editing) ...[
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: l10n.addExercise,
              onPressed: _addExercise,
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'rename') _rename();
              },
              itemBuilder: (context) => [
                PopupMenuItem(value: 'rename', child: Text(l10n.rename)),
              ],
            ),
            TextButton(
              onPressed: () => setState(() => _editing = false),
              child: Text(l10n.done),
            ),
          ] else
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') setState(() => _editing = true);
              },
              itemBuilder: (context) => [
                PopupMenuItem(value: 'edit', child: Text(l10n.edit)),
              ],
            ),
        ],
      ),
      body: empty
          ? _EmptyPastBody(
              editing: _editing,
              onNameSession: () async {
                setState(() => _editing = true);
                await _rename();
              },
              onAddExercise: _addExercise,
              onStartEdit: () => setState(() => _editing = true),
            )
          : WorkoutWidget(
              workout: workout,
              readOnly: !_editing,
              onChanged: _editing
                  ? (w) => widget.repository.saveWorkout(w)
                  : null,
              loadExerciseNames: _editing
                  ? widget.repository.distinctExerciseNames
                  : null,
              loadPreviousReps: _editing
                  ? (name) => widget.repository.lastRepsForExercise(
                        name,
                        excludeWorkoutId: workout.id,
                      )
                  : null,
            ),
    );
  }
}

class _EmptyPastBody extends StatelessWidget {
  final bool editing;
  final VoidCallback onNameSession;
  final VoidCallback onAddExercise;
  final VoidCallback onStartEdit;

  const _EmptyPastBody({
    required this.editing,
    required this.onNameSession,
    required this.onAddExercise,
    required this.onStartEdit,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (!editing) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: FilledButton(
            onPressed: onStartEdit,
            child: Text(l10n.edit),
          ),
        ),
      );
    }
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
    final text = (_fieldCtrl?.text ?? '').trim();
    Navigator.pop(context, text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.addExercise),
      content: Autocomplete<String>(
        optionsBuilder: (value) {
          final q = normalizeExerciseKey(value.text);
          if (q.isEmpty || widget.suggestions.isEmpty) {
            return const Iterable<String>.empty();
          }
          return widget.suggestions
              .where((s) => normalizeExerciseKey(s).contains(q))
              .take(8);
        },
        onSelected: (selection) => Navigator.pop(context, selection.trim()),
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

class _RenameWorkoutDialog extends StatefulWidget {
  final String initialName;

  const _RenameWorkoutDialog({required this.initialName});

  @override
  State<_RenameWorkoutDialog> createState() => _RenameWorkoutDialogState();
}

class _RenameWorkoutDialogState extends State<_RenameWorkoutDialog> {
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
