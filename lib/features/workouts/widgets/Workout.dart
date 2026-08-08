import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gymtracker/features/workouts/models/rep.dart';
import 'package:gymtracker/features/workouts/models/set.dart';
import 'package:gymtracker/features/workouts/models/workouts.dart';

class WorkoutWidget extends StatefulWidget {
  final Workout workout;
  final Future<void> Function(Workout workout)? onChanged;
  final Future<List<String>> Function()? loadExerciseNames;
  final bool readOnly;

  const WorkoutWidget({
    super.key,
    required this.workout,
    this.onChanged,
    this.loadExerciseNames,
    this.readOnly = false,
  });

  @override
  State<WorkoutWidget> createState() => _WorkoutWidgetState();
}

class _WorkoutWidgetState extends State<WorkoutWidget> {
  static const _visibleCols = 5;
  static const _addW = 40.0;
  static const _tipKey = 'tip_long_press_delete';

  Workout get workout => widget.workout;

  final _ctrls = <ScrollController>[];
  bool _syncing = false;

  int? _flashSet;
  int? _flashRep;
  int? _focusCol;
  bool _showLeftFade = false;
  bool _showRightFade = false;

  @override
  void initState() {
    super.initState();
    if (!widget.readOnly) _maybeShowDeleteTip();
  }

  @override
  void didUpdateWidget(covariant WorkoutWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.readOnly && !widget.readOnly) _maybeShowDeleteTip();
  }

  Future<void> _maybeShowDeleteTip() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_tipKey) == true) return;
    await prefs.setBool(_tipKey, true);
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Long-press a set or exercise name to delete'),
          duration: Duration(seconds: 5),
          showCloseIcon: true,
        ),
      );
    });
  }

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
    final right =
        pos.maxScrollExtent > 0.5 && pos.pixels < pos.maxScrollExtent - 0.5;
    if (left == _showLeftFade && right == _showRightFade) return;
    setState(() {
      _showLeftFade = left;
      _showRightFade = right;
    });
  }

  Future<void> _addRep(ExerciseSet set) async {
    if (widget.readOnly) return;
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
    await _notifyChanged();
  }

  Future<void> _editRep(ExerciseSet set, int repIndex) async {
    if (widget.readOnly) return;
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
      set.reps[repIndex] = Rep(
        id: current.id,
        weight: result.$1,
        reps: result.$2,
      );
      _flashSet = setIndex;
      _flashRep = repIndex;
    });
    _clearFlashLater();
    await _notifyChanged();
  }

  Future<void> _editExerciseName(ExerciseSet set) async {
    if (widget.readOnly) return;
    final suggestions =
        await widget.loadExerciseNames?.call() ?? const <String>[];
    if (!mounted) return;
    final name = await showDialog<String>(
      context: context,
      builder: (context) => _EditNameDialog(
        initialName: set.exercise,
        suggestions: suggestions,
      ),
    );
    final trimmed = name?.trim() ?? '';
    if (trimmed.isEmpty || !mounted) return;

    final setIndex = workout.sets.indexOf(set);
    if (setIndex < 0) return;
    setState(() {
      workout.sets[setIndex] = ExerciseSet(
        id: set.id,
        exercise: trimmed,
        reps: set.reps,
      );
    });
    await _notifyChanged();
  }

  Future<void> _deleteRep(ExerciseSet set, int repIndex) async {
    if (widget.readOnly) return;
    if (repIndex < 0 || repIndex >= set.reps.length) return;
    final rep = set.reps[repIndex];

    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Delete set'),
              subtitle: Text('${rep.weight}*${rep.reps}'),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (action != 'delete' || !mounted) return;
    if (repIndex >= set.reps.length) return;

    final removed = set.reps.removeAt(repIndex);
    setState(() {});
    await _notifyChanged();
    if (!mounted) return;

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Set deleted'),
        duration: const Duration(seconds: 4),
        persist: false,
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            set.reps.insert(repIndex, removed);
            if (mounted) setState(() {});
            await _notifyChanged();
          },
        ),
      ),
    );
  }

  Future<void> _deleteExercise(ExerciseSet set) async {
    if (widget.readOnly) return;
    final setIndex = workout.sets.indexOf(set);
    if (setIndex < 0) return;

    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Delete exercise'),
              subtitle: Text(set.exercise),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (action != 'delete' || !mounted) return;
    if (setIndex >= workout.sets.length || workout.sets[setIndex] != set) {
      // list may have shifted; find again
      final i = workout.sets.indexOf(set);
      if (i < 0) return;
      await _removeExerciseAt(i, set);
      return;
    }
    await _removeExerciseAt(setIndex, set);
  }

  Future<void> _removeExerciseAt(int setIndex, ExerciseSet removed) async {
    workout.sets.removeAt(setIndex);
    setState(() {});
    await _notifyChanged();
    if (!mounted) return;

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${removed.exercise} removed'),
        duration: const Duration(seconds: 4),
        persist: false,
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            workout.sets.insert(setIndex, removed);
            if (mounted) setState(() {});
            await _notifyChanged();
          },
        ),
      ),
    );
  }

  Future<void> _notifyChanged() async {
    await widget.onChanged?.call(workout);
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
      final target = (col * cellW - (viewport - cellW) / 2).clamp(0.0, max);
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
        final addW = widget.readOnly ? 0.0 : _addW;
        final setsWidth = constraints.maxWidth - 32 - addW;
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
              readOnly: widget.readOnly,
              onAdd: () => _addRep(sets[i]),
              onEdit: (repIndex) => _editRep(sets[i], repIndex),
              onEditName: () => _editExerciseName(sets[i]),
              onDeleteRep: (repIndex) => _deleteRep(sets[i], repIndex),
              onDeleteExercise: () => _deleteExercise(sets[i]),
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
  final bool readOnly;
  final VoidCallback onAdd;
  final ValueChanged<int> onEdit;
  final VoidCallback onEditName;
  final ValueChanged<int> onDeleteRep;
  final VoidCallback onDeleteExercise;

  const _ExerciseBlock({
    required this.set,
    required this.colCount,
    required this.cellW,
    required this.controller,
    required this.flashRep,
    required this.showLeftFade,
    required this.showRightFade,
    required this.readOnly,
    required this.onAdd,
    required this.onEdit,
    required this.onEditName,
    required this.onDeleteRep,
    required this.onDeleteExercise,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final surface = scheme.surface;

    final nameText = Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text(
        set.exercise,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (readOnly)
          nameText
        else
          InkWell(
            onTap: onEditName,
            onLongPress: onDeleteExercise,
            borderRadius: BorderRadius.circular(4),
            child: nameText,
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
                                          child: _repCell(
                                            scheme: scheme,
                                            index: c,
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
            if (!readOnly)
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

  Widget _repCell({required ColorScheme scheme, required int index}) {
    final child = Align(
      alignment: Alignment.centerLeft,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: flashRep == index ? scheme.primaryContainer : null,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          '${set.reps[index].weight}*${set.reps[index].reps}',
        ),
      ),
    );
    if (readOnly) return child;
    return InkWell(
      onTap: () => onEdit(index),
      onLongPress: () => onDeleteRep(index),
      borderRadius: BorderRadius.circular(4),
      child: child,
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
        TextButton(onPressed: _submit, child: Text(widget.actionLabel)),
      ],
    );
  }
}

class _EditNameDialog extends StatefulWidget {
  final String initialName;
  final List<String> suggestions;

  const _EditNameDialog({
    required this.initialName,
    required this.suggestions,
  });

  @override
  State<_EditNameDialog> createState() => _EditNameDialogState();
}

class _EditNameDialogState extends State<_EditNameDialog> {
  TextEditingController? _fieldCtrl;

  void _submit() {
    final text = _fieldCtrl?.text ?? widget.initialName;
    Navigator.pop(context, text);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit exercise'),
      content: Autocomplete<String>(
        initialValue: TextEditingValue(text: widget.initialName),
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
            decoration: const InputDecoration(labelText: 'exercise'),
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
          child: const Text('cancel'),
        ),
        TextButton(onPressed: _submit, child: const Text('save')),
      ],
    );
  }
}
