import 'package:flutter/material.dart';
import 'package:gymtracker/core/database/app_database.dart';
import 'package:gymtracker/core/services/locale_prefs.dart';
import 'package:gymtracker/features/home/screens/home_screen.dart';
import 'package:gymtracker/features/workouts/repository/workout_repository.dart';
import 'package:gymtracker/l10n/app_localizations.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MainApp());
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  late final Future<AppDatabase> _dbFuture = AppDatabase.open();
  String _localeCode = LocalePrefs.system;

  @override
  void initState() {
    super.initState();
    LocalePrefs.loadCode().then((code) {
      if (!mounted) return;
      setState(() => _localeCode = code);
    });
  }

  Future<void> _setLocaleCode(String code) async {
    await LocalePrefs.saveCode(code);
    if (!mounted) return;
    setState(() => _localeCode = code);
  }

  @override
  Widget build(BuildContext context) {
    final locale = LocalePrefs.localeFromCode(_localeCode);

    return FutureBuilder<AppDatabase>(
      future: _dbFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return MaterialApp(
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) {
                final l10n = AppLocalizations.of(context)!;
                return Scaffold(
                  body: Center(
                    child: Text(l10n.dbError('${snapshot.error}')),
                  ),
                );
              },
            ),
          );
        }
        if (!snapshot.hasData) {
          return MaterialApp(
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
          );
        }
        final repo = WorkoutRepository(snapshot.data!);
        return MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: HomeScreen(
            repository: repo,
            localeCode: _localeCode,
            onLocaleCodeChanged: _setLocaleCode,
          ),
        );
      },
    );
  }
}
