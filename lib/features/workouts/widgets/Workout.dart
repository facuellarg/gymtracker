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
  static const _visibleCols = 5;
  static const _addW = 40.0;

  Workout get workout => widget.workout;

  final _ctrls = <ScrollController>[];
  bool _syncing = false;

  int? _flashSet;
  int? _flashRep;
  int? _focusCol;
  bool _showLeftFade = false;
  bool _showRightFade = false;

  @override
  void dispose() {
    for (final c in _ctrls) {
      c.dispose();
    }
    super.dispose();
  }

  void _ensureControllers(int n) {
    while (_ctrls.length < n) {
      final i = _ctrls.length;
      final c = ScrollController();
      c.addListener(() => _onScroll(i));
      _ctrls.add(c);
    }
    while (_ctrls.length > n) {
      _ctrls.removeLast().dispose();
    }
  }

  void _onScroll(int source) {
    if (_syncing || !_ctrls[source].hasClients) return;
    _syncing = true;
    final offset = _ctrls[source].offset;
    for (var i = 0; i < _ctrls.length; i++) {
      if (i == source || !_ctrls[i].hasClients) continue;
      final max = _ctrls[i].position.maxScrollExtent;
      final target = offset.clamp(0.0, max);
      if ((_ctrls[i].offset - target).abs() > 0.5) {
        _ctrls[i].jumpTo(target);
      }
    }
    _syncing = false;
    _updateFades(source);
  }

  void _updateFades(int from) {
    if (!_ctrls[from].hasClients) return;
    final pos = _ctrls[from].position;
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
      builder: (context) => _RepDialog(
        title: set.exercise,
        actionLabel: 'add',
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
      _focusCol = set.reps.length - 1;
    });
    _clearFlashLater();
  }

  Future<void> _editRep(ExerciseSet set, int repIndex) async {
    final current = set.reps[repIndex];
    final result = await showDialog<(int, int)>(
      context: context,
      builder: (context) => _RepDialog(
        title: set.exercise,
        actionLabel: 'save',
        initialWeight: current.weight,
        initialReps: current.reps,
      ),
    );
    if (result == null || !mounted) return;

    final setIndex = workout.sets.indexOf(set);
    setState(() {
      set.reps[repIndex] = Rep(weight: result.$1, reps: result.$2);
      _flashSet = setIndex;
      _flashRep = repIndex;
    });
    _clearFlashLater();
  }

  void _clearFlashLater() {
    Future<void>.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      setState(() {
        _flashSet = null;
        _flashRep = null;
      });
    });
  }

  void _scrollToAdded(double cellW, int colCount) {
    final col = _focusCol;
    if (col == null) return;
    _focusCol = null;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_ctrls.isEmpty || !_ctrls.first.hasClients || colCount == 0) return;
      final pos = _ctrls.first.position;
      final max = pos.maxScrollExtent;
      if (max <= 0) return;
      final viewport = pos.viewportDimension;
      final target =
          (col * cellW - (viewport - cellW) / 2).clamp(0.0, max);
      _syncing = true;
      for (final c in _ctrls) {
        if (!c.hasClients) continue;
        c.animateTo(
          target.clamp(0.0, c.position.maxScrollExtent),
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
        );
      }
      _syncing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final sets = workout.sets;
    _ensureControllers(sets.length);

    final colCount = sets.fold<int>(
      0,
      (max, set) => set.reps.length > max ? set.reps.length : max,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final setsWidth = constraints.maxWidth - 32 - _addW; // padding + add
        final slots = colCount == 0
            ? 1
            : (colCount <= _visibleCols ? colCount : _visibleCols);
        final cellW = setsWidth / slots;
        _scrollToAdded(cellW, colCount);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_ctrls.isNotEmpty) _updateFades(0);
        });

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: sets.length,
          separatorBuilder: (_, _) => const SizedBox(height: 16),
          itemBuilder: (context, i) {
            return _ExerciseBlock(
              set: sets[i],
              colCount: colCount,
              cellW: cellW,
              controller: _ctrls[i],
              flashRep: _flashSet == i ? _flashRep : null,
              showLeftFade: _showLeftFade,
              showRightFade: _showRightFade,
              onAdd: () => _addRep(sets[i]),
              onEdit: (repIndex) => _editRep(sets[i], repIndex),
            );
          },
        );
      },
    );
  }
}

class _ExerciseBlock extends StatelessWidget {
  static const _rowH = 40.0;
  static const _fadeW = 24.0;

  final ExerciseSet set;
  final int colCount;
  final double cellW;
  final ScrollController controller;
  final int? flashRep;
  final bool showLeftFade;
  final bool showRightFade;
  final VoidCallback onAdd;
  final ValueChanged<int> onEdit;

  const _ExerciseBlock({
    required this.set,
    required this.colCount,
    required this.cellW,
    required this.controller,
    required this.flashRep,
    required this.showLeftFade,
    required this.showRightFade,
    required this.onAdd,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final surface = scheme.surface;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          set.exercise,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        Divider(
          height: 1,
          thickness: 1,
          color: scheme.outlineVariant.withValues(alpha: 0.5),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: Stack(
                children: [
                  SingleChildScrollView(
                    controller: controller,
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      height: _rowH,
                      child: Row(
                        children: [
                          for (var c = 0; c < colCount; c++)
                            SizedBox(
                              width: cellW,
                              child: c < set.reps.length
                                  ? Row(
                                      children: [
                                        if (c > 0)
                                          Container(
                                            width: 1,
                                            height: 18,
                                            margin: const EdgeInsets.only(
                                              right: 6,
                                            ),
                                            color: scheme.outlineVariant
                                                .withValues(alpha: 0.5),
                                          ),
                                        Expanded(
                                          child: InkWell(
                                            onTap: () => onEdit(c),
                                            borderRadius:
                                                BorderRadius.circular(4),
                                            child: Align(
                                              alignment: Alignment.centerLeft,
                                              child: AnimatedContainer(
                                                duration: const Duration(
                                                  milliseconds: 250,
                                                ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 4,
                                                  vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: flashRep == c
                                                      ? scheme.primaryContainer
                                                      : null,
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  '${set.reps[c].weight}'
                                                  '*${set.reps[c].reps}',
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    )
                                  : null,
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (showLeftFade)
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      width: _fadeW,
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [surface, surface.withValues(alpha: 0)],
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (showRightFade)
                    Positioned(
                      right: 0,
                      top: 0,
                      bottom: 0,
                      width: _fadeW,
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [surface.withValues(alpha: 0), surface],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(
              width: 40,
              height: _rowH,
              child: IconButton(
                icon: const Icon(Icons.add, size: 20),
                onPressed: onAdd,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _RepDialog extends StatefulWidget {
  final String title;
  final String actionLabel;
  final int? initialWeight;
  final int? initialReps;

  const _RepDialog({
    required this.title,
    required this.actionLabel,
    this.initialWeight,
    this.initialReps,
  });

  @override
  State<_RepDialog> createState() => _RepDialogState();
}

class _RepDialogState extends State<_RepDialog> {
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
        TextButton(
          onPressed: _submit,
          child: Text(widget.actionLabel),
        ),
      ],
    );
  }
}
