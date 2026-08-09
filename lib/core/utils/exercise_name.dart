/// Trim + lowercase key for matching exercise names.
String normalizeExerciseKey(String name) => name.trim().toLowerCase();

/// Best exercise display name for [query]: exact, then prefix, then contains.
String? matchExerciseName(
  Iterable<({String exercise})> exercises,
  String query,
) {
  final q = normalizeExerciseKey(query);
  if (q.isEmpty) return null;
  String? exact;
  String? prefix;
  String? partial;
  for (final e in exercises) {
    final name = e.exercise.trim();
    if (name.isEmpty) continue;
    final key = normalizeExerciseKey(name);
    if (key == q) {
      exact ??= name;
    } else if (key.startsWith(q)) {
      prefix ??= name;
    } else if (key.contains(q)) {
      partial ??= name;
    }
  }
  return exact ?? prefix ?? partial;
}

/// Autocomplete candidates that contain [query].
/// Prefix matches first, then other contains matches (e.g. pecho → pecho, then jalon de pecho).
Iterable<String> exerciseNameSuggestions(
  Iterable<String> catalog,
  String query, {
  int limit = 8,
}) {
  final q = normalizeExerciseKey(query);
  if (q.isEmpty) return const Iterable<String>.empty();

  final prefix = <String>[];
  final rest = <String>[];
  for (final name in catalog) {
    final key = normalizeExerciseKey(name);
    if (key.startsWith(q)) {
      prefix.add(name);
    } else if (key.contains(q)) {
      rest.add(name);
    }
  }
  return [...prefix, ...rest].take(limit);
}

String formatRepsPreview(Iterable<({int weight, int reps})> reps) =>
    reps.map((r) => '${r.weight}*${r.reps}').join(' | ');
