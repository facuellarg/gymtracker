import 'package:flutter/material.dart';
import 'package:gymtracker/features/workouts/models/rep.dart';
import 'package:gymtracker/features/workouts/models/set.dart';
import 'package:gymtracker/features/workouts/models/workouts.dart';
import 'package:gymtracker/features/workouts/widgets/Workout.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _query = TextEditingController();

  // ponytail: in-memory samples until persistence exists
  late final List<Workout> _sessions = [
    Workout(
      name: 'Today',
      date: DateTime.now(),
      sets: [
        ExerciseSet(
          exercise: 'bench',
          reps: [Rep(weight: 70, reps: 8), Rep(weight: 70, reps: 8)],
        ),
        ExerciseSet(
          exercise: 'squats',
          reps: [Rep(weight: 100, reps: 10)],
        ),
      ],
    ),
    Workout(
      name: 'Pull',
      date: DateTime.now().subtract(const Duration(days: 2)),
      sets: [
        ExerciseSet(
          exercise: 'deadlifts',
          reps: [Rep(weight: 120, reps: 5), Rep(weight: 130, reps: 5)],
        ),
        ExerciseSet(
          exercise: 'rows',
          reps: [Rep(weight: 60, reps: 10)],
        ),
      ],
    ),
    Workout(
      name: 'Push',
      date: DateTime.now().subtract(const Duration(days: 5)),
      sets: [
        ExerciseSet(
          exercise: 'bench',
          reps: [Rep(weight: 65, reps: 8)],
        ),
        ExerciseSet(
          exercise: 'ohp',
          reps: [Rep(weight: 40, reps: 8)],
        ),
      ],
    ),
  ];

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  String _dateLabel(DateTime date) {
    final now = DateTime.now();
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return 'Today';
    }
    return '${date.month}/${date.day}/${date.year}';
  }

  String _preview(Workout w) =>
      w.sets.map((s) => s.exercise).join(', ');

  List<Workout> get _filtered {
    final q = _query.text.trim().toLowerCase();
    final list = [..._sessions]
      ..sort((a, b) => b.date.compareTo(a.date));
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
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => Scaffold(
          appBar: AppBar(title: Text(_dateLabel(workout.date))),
          body: WorkoutWidget(workout: workout),
        ),
      ),
    );
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
            child: sessions.isEmpty
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

                      return ListTile(
                        title: hasCustomName
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: textTheme.titleMedium,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(dateLabel, style: textTheme.labelMedium),
                                ],
                              )
                            : Text(dateLabel, style: textTheme.titleMedium),
                        subtitle: Text(
                          _preview(w),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
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
