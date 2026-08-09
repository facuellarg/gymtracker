// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get navLog => 'Registro';

  @override
  String get navHistory => 'Historial';

  @override
  String get today => 'Hoy';

  @override
  String get history => 'Historial';

  @override
  String get addExercise => 'Añadir ejercicio';

  @override
  String get rename => 'Renombrar';

  @override
  String get nameThisSession => 'Nombrar sesión';

  @override
  String get noWorkoutYet => 'Sin entrenamiento aún';

  @override
  String get exercise => 'ejercicio';

  @override
  String get cancel => 'cancelar';

  @override
  String get add => 'añadir';

  @override
  String get save => 'guardar';

  @override
  String get editWorkout => 'Editar entrenamiento';

  @override
  String get name => 'nombre';

  @override
  String failedToLoad(String error) {
    return 'Error al cargar: $error';
  }

  @override
  String dbError(String error) {
    return 'Error de BD: $error';
  }

  @override
  String get searchHint => 'Buscar por entrenamiento o ejercicio';

  @override
  String viewExercise(String name) {
    return 'Ver $name';
  }

  @override
  String lastSession(String preview) {
    return 'último: $preview';
  }

  @override
  String get noExerciseHistory => 'Sin historial para este ejercicio';

  @override
  String get noSessions => 'Sin sesiones';

  @override
  String get addPastWorkout => 'Añadir entrenamiento pasado';

  @override
  String get continueInLog => 'Continuar en Registro';

  @override
  String get done => 'Listo';

  @override
  String get edit => 'Editar';

  @override
  String get deleteTip =>
      'Mantén pulsado un set o el nombre del ejercicio para borrar';

  @override
  String get deleteSet => 'Borrar set';

  @override
  String get deleteExercise => 'Borrar ejercicio';

  @override
  String get deleteWorkout => 'Borrar entrenamiento';

  @override
  String get workoutDeleted => 'Entrenamiento borrado';

  @override
  String get setDeleted => 'Set borrado';

  @override
  String exerciseRemoved(String exercise) {
    return '$exercise eliminado';
  }

  @override
  String get undo => 'Deshacer';

  @override
  String get weight => 'peso';

  @override
  String get reps => 'reps';

  @override
  String get editExercise => 'Editar ejercicio';

  @override
  String get settings => 'Ajustes';

  @override
  String get language => 'Idioma';

  @override
  String get languageSystem => 'Idioma del sistema';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageSpanish => 'Español';

  @override
  String get backup => 'Copia de seguridad';

  @override
  String get exportWorkouts => 'Exportar entrenamientos';

  @override
  String get exportWorkoutsHint =>
      'Guarda un JSON para conservarlo o compartirlo';

  @override
  String get exportDone => 'Copia guardada';

  @override
  String get importWorkouts => 'Importar entrenamientos';

  @override
  String get importWorkoutsHint => 'Carga entrenamientos desde un JSON';

  @override
  String importDone(int count) {
    return 'Se importaron $count entrenamientos';
  }

  @override
  String exportFailed(String error) {
    return 'Error al exportar: $error';
  }

  @override
  String importFailed(String error) {
    return 'Error al importar: $error';
  }
}
