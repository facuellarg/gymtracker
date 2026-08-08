import 'package:flutter/material.dart';
import 'package:gymtracker/features/workouts/models/workouts.dart';
import 'package:gymtracker/features/workouts/repository/workout_repository.dart';
import 'package:gymtracker/features/workouts/widgets/Workout.dart';

class HistoryScreen extends StatefulWidget {
  final WorkoutRepository repository;
  final VoidCallback onOpenToday;

  const HistoryScreen({
    super.key,
    required this.repository,
    required this.onOpenToday,
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

  String _dateLabel(DateTime date) {
    if (_isToday(date)) return 'Today';
    return '${date.month}/${date.day}/${date.year}';
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

  void _openSession(Workout workout) {
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
              dateLabel: _dateLabel(workout.date),
            ),
          ),
        )
        .then((_) {
          if (mounted) reload();
        });
  }

  @override
  Widget build(BuildContext context) {
    final sessions = _filtered;

    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _query,
              decoration: const InputDecoration(
                hintText: 'Search by workout or exercise',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : sessions.isEmpty
                    ? const Center(child: Text('No sessions'))
                    : ListView.separated(
                        itemCount: sessions.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final w = sessions[i];
                          final dateLabel = _dateLabel(w.date);
                          final name = w.name.trim();
                          final hasCustomName =
                              name.isNotEmpty && name != dateLabel;
                          final textTheme = Theme.of(context).textTheme;
                          final isToday = _isToday(w.date);

                          return ListTile(
                            title: hasCustomName
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
                              isToday
                                  ? 'Continue in Log'
                                  : _preview(w),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: isToday
                                ? const Icon(Icons.edit_note)
                                : null,
                            onTap: () => _openSession(w),
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

  const _HistoryDetailPage({
    required this.workout,
    required this.repository,
    required this.dateLabel,
  });

  @override
  State<_HistoryDetailPage> createState() => _HistoryDetailPageState();
}

class _HistoryDetailPageState extends State<_HistoryDetailPage> {
  bool _editing = false;

  Future<void> _rename() async {
    final workout = widget.workout;
    final dateLabel = widget.dateLabel;
    final initial =
        workout.name.trim().isEmpty ? dateLabel : workout.name.trim();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => _RenameWorkoutDialog(initialName: initial),
    );
    final trimmed = name?.trim() ?? '';
    if (trimmed.isEmpty || !mounted) return;
    setState(() => workout.name = trimmed);
    await widget.repository.saveWorkout(workout);
  }

  @override
  Widget build(BuildContext context) {
    final workout = widget.workout;
    final dateLabel = widget.dateLabel;
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
          if (_editing) ...[
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'rename') _rename();
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'rename', child: Text('Rename')),
              ],
            ),
            TextButton(
              onPressed: () => setState(() => _editing = false),
              child: const Text('Done'),
            ),
          ] else
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') setState(() => _editing = true);
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit')),
              ],
            ),
        ],
      ),
      body: WorkoutWidget(
        workout: workout,
        readOnly: !_editing,
        onChanged: _editing
            ? (w) => widget.repository.saveWorkout(w)
            : null,
        loadExerciseNames: _editing
            ? widget.repository.distinctExerciseNames
            : null,
      ),
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
