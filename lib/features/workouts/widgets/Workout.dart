import 'package:flutter/material.dart';
import 'package:gymtracker/features/workouts/models/rep.dart';
import 'package:gymtracker/features/workouts/models/set.dart';
import 'package:gymtracker/features/workouts/models/workouts.dart';

class WorkoutWidget extends StatefulWidget {
  final Workout workout;

  const WorkoutWidget({super.key, required this.workout});

  @override
  State<WorkoutWidget> createState() => _WorkoutWidgetState();
}

class _WorkoutWidgetState extends State<WorkoutWidget> {
  static const _rowH = 48.0;
  static const _nameW = 110.0;
  static const _visibleCols = 5;
  static const _fadeW = 24.0;

  final _hScroll = ScrollController();

  Workout get workout => widget.workout;

  int? _flashSet;
  int? _flashRep;
  int? _scrollToCol;
  bool _showLeftFade = false;
  bool _showRightFade = false;

  @override
  void initState() {
    super.initState();
    _hScroll.addListener(_updateFades);
  }

  @override
  void dispose() {
    _hScroll.removeListener(_updateFades);
    _hScroll.dispose();
    super.dispose();
  }

  void _updateFades() {
    if (!_hScroll.hasClients) return;
    final pos = _hScroll.position;
    final left = pos.pixels > 0.5;
    final right = pos.maxScrollExtent > 0.5 &&
        pos.pixels < pos.maxScrollExtent - 0.5;
    if (left == _showLeftFade && right == _showRightFade) return;
    setState(() {
      _showLeftFade = left;
      _showRightFade = right;
    });
  }

  Future<void> _addRep(ExerciseSet set) async {
    final result = await showDialog<(int, int)>(
      context: context,
      builder: (context) => _AddRepDialog(
        title: set.exercise,
        initialWeight: set.reps.isEmpty ? null : set.reps.last.weight,
        initialReps: set.reps.isEmpty ? null : set.reps.last.reps,
      ),
    );
    if (result == null || !mounted) return;

    final setIndex = workout.sets.indexOf(set);
    setState(() {
      set.reps.add(Rep(weight: result.$1, reps: result.$2));
      _flashSet = setIndex;
      _flashRep = set.reps.length - 1;
      _scrollToCol = set.reps.length - 1;
    });

    Future<void>.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      setState(() {
        _flashSet = null;
        _flashRep = null;
      });
    });
  }

  void _scrollToAdded(double cellW, int colCount) {
    final col = _scrollToCol;
    if (col == null) return;
    _scrollToCol = null;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_hScroll.hasClients || colCount == 0) return;
      final max = _hScroll.position.maxScrollExtent;
      if (max <= 0) return;
      final viewport = _hScroll.position.viewportDimension;
      final target =
          (col * cellW - (viewport - cellW) / 2).clamp(0.0, max);
      _hScroll.animateTo(
        target,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final colCount = workout.sets.fold<int>(
      0,
      (max, set) => set.reps.length > max ? set.reps.length : max,
    );
    final rows = workout.sets.length + 1;
    final scheme = Theme.of(context).colorScheme;

    Widget nameCell(int i) {
      final header = i == 0;
      return SizedBox(
        height: _rowH,
        width: _nameW,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            header ? 'name' : workout.sets[i - 1].exercise,
            style: header ? const TextStyle(fontWeight: FontWeight.bold) : null,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    }

    Widget setCells(int i, double cellW) {
      final header = i == 0;
      final set = header ? null : workout.sets[i - 1];
      final style =
          header ? const TextStyle(fontWeight: FontWeight.bold) : null;
      return SizedBox(
        height: _rowH,
        child: Row(
          children: [
            for (var c = 0; c < colCount; c++)
              SizedBox(
                width: cellW,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: !header &&
                              _flashSet == i - 1 &&
                              _flashRep == c
                          ? scheme.primaryContainer
                          : null,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      header
                          ? 'w/rep'
                          : c < set!.reps.length
                              ? '${set.reps[c].weight}*${set.reps[c].reps}'
                              : '',
                      style: style,
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    }

    Widget addCell(int i) {
      if (i == 0) return const SizedBox(height: _rowH, width: 40);
      final set = workout.sets[i - 1];
      return SizedBox(
        height: _rowH,
        width: 40,
        child: IconButton(
          icon: const Icon(Icons.add, size: 20),
          onPressed: () => _addRep(set),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(children: [for (var i = 0; i < rows; i++) nameCell(i)]),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final slots =
                      colCount == 0
                          ? 1
                          : (colCount <= _visibleCols
                              ? colCount
                              : _visibleCols);
                  final cellW = constraints.maxWidth / slots;
                  _scrollToAdded(cellW, colCount);
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _updateFades();
                  });

                  final surface = Theme.of(context).colorScheme.surface;
                  return Stack(
                    children: [
                      SingleChildScrollView(
                        controller: _hScroll,
                        scrollDirection: Axis.horizontal,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (var i = 0; i < rows; i++)
                              setCells(i, cellW),
                          ],
                        ),
                      ),
                      if (_showLeftFade)
                        Positioned(
                          left: 0,
                          top: 0,
                          bottom: 0,
                          width: _fadeW,
                          child: IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    surface,
                                    surface.withValues(alpha: 0),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (_showRightFade)
                        Positioned(
                          right: 0,
                          top: 0,
                          bottom: 0,
                          width: _fadeW,
                          child: IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    surface.withValues(alpha: 0),
                                    surface,
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
            Column(children: [for (var i = 0; i < rows; i++) addCell(i)]),
          ],
        ),
      ),
    );
  }
}

class _AddRepDialog extends StatefulWidget {
  final String title;
  final int? initialWeight;
  final int? initialReps;

  const _AddRepDialog({
    required this.title,
    this.initialWeight,
    this.initialReps,
  });

  @override
  State<_AddRepDialog> createState() => _AddRepDialogState();
}

class _AddRepDialogState extends State<_AddRepDialog> {
  late final _weightCtrl = TextEditingController(
    text: widget.initialWeight?.toString() ?? '',
  );
  late final _repsCtrl = TextEditingController(
    text: widget.initialReps?.toString() ?? '',
  );

  @override
  void dispose() {
    _weightCtrl.dispose();
    _repsCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final weight = int.tryParse(_weightCtrl.text);
    final reps = int.tryParse(_repsCtrl.text);
    if (weight == null || reps == null) return;
    Navigator.pop(context, (weight, reps));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _weightCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'weight'),
            autofocus: true,
          ),
          TextField(
            controller: _repsCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'reps'),
            onSubmitted: (_) => _submit(),
          ),
        ],
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
