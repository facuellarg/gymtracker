import 'package:flutter/material.dart';
import 'package:gymtracker/core/database/app_database.dart';
import 'package:gymtracker/features/home/screens/home_screen.dart';
import 'package:gymtracker/features/workouts/repository/workout_repository.dart';

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

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppDatabase>(
      future: _dbFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return MaterialApp(
            home: Scaffold(
              body: Center(child: Text('DB error: ${snapshot.error}')),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const MaterialApp(
            home: Scaffold(body: Center(child: CircularProgressIndicator())),
          );
        }
        final repo = WorkoutRepository(snapshot.data!);
        return MaterialApp(home: HomeScreen(repository: repo));
      },
    );
  }
}
