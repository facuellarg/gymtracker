import 'package:flutter/material.dart';
import 'package:gymtracker/l10n/app_localizations.dart';
import 'package:intl/intl.dart';

/// DB sentinel for untitled default sessions (never localized in storage).
const defaultWorkoutName = 'Today';

bool isDefaultWorkoutName(String name) {
  final t = name.trim();
  return t.isEmpty || t == defaultWorkoutName;
}

bool hasCustomWorkoutName(String name) => !isDefaultWorkoutName(name);

String workoutDateLabel(BuildContext context, DateTime date, {bool withYear = false}) {
  final l10n = AppLocalizations.of(context)!;
  final now = DateTime.now();
  if (date.year == now.year && date.month == now.month && date.day == now.day) {
    return l10n.today;
  }
  final locale = Localizations.localeOf(context).toString();
  final pattern = withYear ? 'yMd' : 'Md';
  return DateFormat(pattern, locale).format(date);
}
