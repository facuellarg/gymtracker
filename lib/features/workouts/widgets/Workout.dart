import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gymtracker/core/utils/exercise_name.dart';
import 'package:gymtracker/features/workouts/models/rep.dart';
import 'package:gymtracker/features/workouts/models/set.dart';
import 'package:gymtracker/features/workouts/models/workouts.dart';
import 'package:gymtracker/l10n/app_localizations.dart';

class WorkoutWidget extends StatefulWidget {
  final Workout workout;
  final Future<void> Function(Workout workout)? onChanged;
  final Future<List<String>> Function()? loadExerciseNames;
  final Future<List<Rep>> Function(String exercise)? loadPreviousReps;
  final bool readOnly;

  const WorkoutWidget({
    super.key,
    required this.workout,
    this.onChanged,
    this.loadExerciseNames,
    this.loadPreviousReps,
    this.readOnly = false,
  });

  @override
  State<WorkoutWidget> createState() => _WorkoutWidgetState();
}

class _WorkoutWidgetState extends State<WorkoutWidget> {
  static const _visibleCols = 5;
  static const _addW = 48.0;
  static const _tipKey = 'tip_long_press_delete';
  static const _maxGhosts = 5;

  Workout get workout => widget.workout;

  final _ctrls = <ScrollController>[];
  bool _syncing = false;

  /// Previous-session reps by [normalizeExerciseKey].
  Map<String, List<Rep>> _previous = {};

  int? _flashSet;
  int? _flashRep;
  int? _focusCol;
  bool _showLeftFade = false;
  bool _showRightFade = false;

  @override
  void initState() {
    super.initState();
    if (!widget.readOnly) {
      _maybeShowDeleteTip();
      _refreshPrevious();
    }
  }

  @override
  void didUpdateWidget(covariant WorkoutWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.readOnly && !widget.readOnly) {
      _maybeShowDeleteTip();
      _refreshPrevious();
    } else if (!widget.readOnly &&
        _exerciseKeys(oldWidget.workout) != _exerciseKeys(workout)) {
      _refreshPrevious();
    }
  }

  Set<String> _exerciseKeys(Workout w) => {
        for (final s in w.sets) normalizeExerciseKey(s.exercise),
      };

  List<Rep> _ghostsFor(ExerciseSet set) {
    if (widget.readOnly || set.reps.isNotEmpty) return const [];
    final list = _previous[normalizeExerciseKey(set.exercise)];
    if (list == null || list.isEmpty) return const [];
    return list.length <= _maxGhosts ? list : list.sublist(0, _maxGhosts);
  }

  Future<void> _refreshPrevious() async {
    final loader = widget.loadPreviousReps;
    if (widget.readOnly || loader == null) {
      if (_previous.isNotEmpty && mounted) setState(() => _previous = {});
      return;
    }
    final next = <String, List<Rep>>{};
    for (final set in workout.sets) {
      final key = normalizeExerciseKey(set.exercise);
      if (key.isEmpty || next.containsKey(key)) continue;
      next[key] = await loader(set.exercise);
    }
    if (!mounted) return;
    setState(() => _previous = next);
  }

  Future<void> _maybeShowDeleteTip() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_tipKey) == true) return;
    await prefs.setBool(_tipKey, true);
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.deleteTip),
          duration: const Duration(seconds: 5),
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

  Future<void> _addRep(ExerciseSet set, {Rep? suggest}) async {
    if (widget.readOnly) return;
    final l10n = AppLocalizations.of(context)!;
    final ghosts = _ghostsFor(set);
    final fromToday = set.reps.isNotEmpty ? set.reps.last : null;
    final fromPrev = suggest ?? (ghosts.isNotEmpty ? ghosts.first : null);
    final result = await showDialog<(int, int)>(
      context: context,
      builder: (context) => _RepDialog(
        title: set.exercise,
        actionLabel: l10n.add,
        initialWeight: fromToday?.weight ?? fromPrev?.weight,
        initialReps: fromToday?.reps ?? fromPrev?.reps,
      ),
    );
    if (result == null || !mounted) return;

    HapticFeedback.lightImpact();
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
    final l10n = AppLocalizations.of(context)!;
    final current = set.reps[repIndex];
    final result = await showDialog<(int, int)>(
      context: context,
      builder: (context) => _RepDialog(
        title: set.exercise,
        actionLabel: l10n.save,
        initialWeight: current.weight,
        initialReps: current.reps,
      ),
    );
    if (result == null || !mounted) return;

    HapticFeedback.selectionClick();
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
    await _refreshPrevious();
  }

  Future<void> _deleteRep(ExerciseSet set, int repIndex) async {
    if (widget.readOnly) return;
    if (repIndex < 0 || repIndex >= set.reps.length) return;
    final rep = set.reps[repIndex];

    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        final error = Theme.of(context).colorScheme.error;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.delete_outline, color: error),
                title: Text(l10n.deleteSet, style: TextStyle(color: error)),
                subtitle: Text('${rep.weight}*${rep.reps}'),
                onTap: () => Navigator.pop(context, 'delete'),
              ),
            ],
          ),
        );
      },
    );
    if (action != 'delete' || !mounted) return;
    if (repIndex >= set.reps.length) return;

    HapticFeedback.mediumImpact();
    final removed = set.reps.removeAt(repIndex);
    setState(() {});
    await _notifyChanged();
    if (!mounted) return;

    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.setDeleted),
        duration: const Duration(seconds: 4),
        persist: false,
        action: SnackBarAction(
          label: l10n.undo,
          onPressed: () async {
            HapticFeedback.selectionClick();
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
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        final error = Theme.of(context).colorScheme.error;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.delete_outline, color: error),
                title: Text(
                  l10n.deleteExercise,
                  style: TextStyle(color: error),
                ),
                subtitle: Text(set.exercise),
                onTap: () => Navigator.pop(context, 'delete'),
              ),
            ],
          ),
        );
      },
    );
    if (action != 'delete' || !mounted) return;
    if (setIndex >= workout.sets.length || workout.sets[setIndex] != set) {
      final i = workout.sets.indexOf(set);
      if (i < 0) return;
      await _removeExerciseAt(i, set);
      return;
    }
    await _removeExerciseAt(setIndex, set);
  }

  Future<void> _removeExerciseAt(int setIndex, ExerciseSet removed) async {
    HapticFeedback.mediumImpact();
    workout.sets.removeAt(setIndex);
    setState(() {});
    await _notifyChanged();
    if (!mounted) return;

    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.exerciseRemoved(removed.exercise)),
        duration: const Duration(seconds: 4),
        persist: false,
        action: SnackBarAction(
          label: l10n.undo,
          onPressed: () async {
            HapticFeedback.selectionClick();
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

    final colCount = sets.fold<int>(0, (max, set) {
      final ghosts = _ghostsFor(set).length;
      final n = set.reps.length > ghosts ? set.reps.length : ghosts;
      return n > max ? n : max;
    });

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
            final set = sets[i];
            final ghosts = _ghostsFor(set);
            return _ExerciseBlock(
              set: set,
              ghosts: ghosts,
              colCount: colCount,
              cellW: cellW,
              controller: _ctrls[i],
              flashRep: _flashSet == i ? _flashRep : null,
              showLeftFade: _showLeftFade,
              showRightFade: _showRightFade,
              readOnly: widget.readOnly,
              onAdd: () => _addRep(set),
              onEdit: (repIndex) => _editRep(set, repIndex),
              onGhostTap: (g) => _addRep(set, suggest: g),
              onEditName: () => _editExerciseName(set),
              onDeleteRep: (repIndex) => _deleteRep(set, repIndex),
              onDeleteExercise: () => _deleteExercise(set),
            );
          },
        );
      },
    );
  }
}

class _ExerciseBlock extends StatelessWidget {
  static const _rowH = 48.0;
  static const _fadeW = 24.0;
  static const _setStyle = TextStyle(
    fontFeatures: [FontFeature.tabularFigures()],
  );

  final ExerciseSet set;
  final List<Rep> ghosts;
  final int colCount;
  final double cellW;
  final ScrollController controller;
  final int? flashRep;
  final bool showLeftFade;
  final bool showRightFade;
  final bool readOnly;
  final VoidCallback onAdd;
  final ValueChanged<int> onEdit;
  final ValueChanged<Rep> onGhostTap;
  final VoidCallback onEditName;
  final ValueChanged<int> onDeleteRep;
  final VoidCallback onDeleteExercise;

  const _ExerciseBlock({
    required this.set,
    required this.ghosts,
    required this.colCount,
    required this.cellW,
    required this.controller,
    required this.flashRep,
    required this.showLeftFade,
    required this.showRightFade,
    required this.readOnly,
    required this.onAdd,
    required this.onEdit,
    required this.onGhostTap,
    required this.onEditName,
    required this.onDeleteRep,
    required this.onDeleteExercise,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final surface = scheme.surface;
    final nameStyle = Theme.of(context).textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
        );

    final nameText = Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(set.exercise, style: nameStyle),
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
        Divider(
          height: 1,
          thickness: 1,
          color: scheme.outlineVariant.withValues(alpha: 0.5),
        ),
        const SizedBox(height: 6),
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
                                  : c < ghosts.length
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
                                                    .withValues(alpha: 0.35),
                                              ),
                                            Expanded(
                                              child: _ghostCell(
                                                scheme: scheme,
                                                rep: ghosts[c],
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
                width: 48,
                height: _rowH,
                child: IconButton.filledTonal(
                  icon: const Icon(Icons.add, size: 20),
                  onPressed: onAdd,
                  padding: EdgeInsets.zero,
                  style: IconButton.styleFrom(
                    minimumSize: const Size(40, 40),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
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
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        decoration: BoxDecoration(
          color: flashRep == index ? scheme.primaryContainer : null,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          '${set.reps[index].weight}*${set.reps[index].reps}',
          style: _setStyle,
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

  Widget _ghostCell({required ColorScheme scheme, required Rep rep}) {
    return InkWell(
      onTap: () => onGhostTap(rep),
      borderRadius: BorderRadius.circular(4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Text(
            '${rep.weight}*${rep.reps}',
            style: _setStyle.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.38),
              fontStyle: FontStyle.italic,
              decoration: TextDecoration.underline,
              decorationStyle: TextDecorationStyle.dotted,
              decorationColor: scheme.onSurface.withValues(alpha: 0.28),
            ),
          ),
        ),
      ),
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
  final _repsFocus = FocusNode();

  @override
  void dispose() {
    _weightCtrl.dispose();
    _repsCtrl.dispose();
    _repsFocus.dispose();
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
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      scrollable: true,
      title: Text(widget.title),
      content: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: TextField(
              controller: _weightCtrl,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(labelText: l10n.weight),
              autofocus: true,
              onSubmitted: (_) => _repsFocus.requestFocus(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _repsCtrl,
              focusNode: _repsFocus,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(labelText: l10n.reps),
              onSubmitted: (_) => _submit(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(widget.actionLabel)),
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
    Navigator.pop(context, text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.editExercise),
      content: Autocomplete<String>(
        initialValue: TextEditingValue(text: widget.initialName),
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
        FilledButton(onPressed: _submit, child: Text(l10n.save)),
      ],
    );
  }
}
