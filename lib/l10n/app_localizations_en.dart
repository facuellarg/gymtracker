// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get navLog => 'Log';

  @override
  String get navHistory => 'History';

  @override
  String get today => 'Today';

  @override
  String get history => 'History';

  @override
  String get addExercise => 'Add exercise';

  @override
  String get rename => 'Rename';

  @override
  String get nameThisSession => 'Name this session';

  @override
  String get noWorkoutYet => 'No workout yet';

  @override
  String get exercise => 'exercise';

  @override
  String get cancel => 'cancel';

  @override
  String get add => 'add';

  @override
  String get save => 'save';

  @override
  String get editWorkout => 'Edit workout';

  @override
  String get name => 'name';

  @override
  String failedToLoad(String error) {
    return 'Failed to load: $error';
  }

  @override
  String dbError(String error) {
    return 'DB error: $error';
  }

  @override
  String get searchHint => 'Search by workout or exercise';

  @override
  String viewExercise(String name) {
    return 'View $name';
  }

  @override
  String lastSession(String preview) {
    return 'last: $preview';
  }

  @override
  String get noExerciseHistory => 'No history for this exercise';

  @override
  String get noSessions => 'No sessions';

  @override
  String get addPastWorkout => 'Add past workout';

  @override
  String get continueInLog => 'Continue in Log';

  @override
  String get done => 'Done';

  @override
  String get edit => 'Edit';

  @override
  String get deleteTip => 'Long-press a set or exercise name to delete';

  @override
  String get deleteSet => 'Delete set';

  @override
  String get deleteExercise => 'Delete exercise';

  @override
  String get deleteWorkout => 'Delete workout';

  @override
  String get workoutDeleted => 'Workout deleted';

  @override
  String get setDeleted => 'Set deleted';

  @override
  String exerciseRemoved(String exercise) {
    return '$exercise removed';
  }

  @override
  String get undo => 'Undo';

  @override
  String get weight => 'weight';

  @override
  String get reps => 'reps';

  @override
  String get editExercise => 'Edit exercise';

  @override
  String get settings => 'Settings';

  @override
  String get language => 'Language';

  @override
  String get languageSystem => 'System default';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageSpanish => 'Español';

  @override
  String get backup => 'Backup';

  @override
  String get exportWorkouts => 'Export workouts';

  @override
  String get exportWorkoutsHint => 'Save a JSON file you can keep or share';

  @override
  String get exportDone => 'Backup saved';

  @override
  String get importWorkouts => 'Import workouts';

  @override
  String get importWorkoutsHint => 'Load workouts from a JSON backup';

  @override
  String importDone(int count) {
    return 'Imported $count workouts';
  }

  @override
  String exportFailed(String error) {
    return 'Export failed: $error';
  }

  @override
  String importFailed(String error) {
    return 'Import failed: $error';
  }
}
