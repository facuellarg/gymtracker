import 'package:flutter/material.dart';
import 'package:gymtracker/features/history/screens/history_screen.dart';
import 'package:gymtracker/features/workouts/repository/workout_repository.dart';
import 'package:gymtracker/features/workouts/screens/workout_screen.dart';

class HomeScreen extends StatefulWidget {
  final WorkoutRepository repository;

  const HomeScreen({super.key, required this.repository});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;
  final _historyKey = GlobalKey<HistoryScreenState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: [
          WorkoutScreen(repository: widget.repository),
          HistoryScreen(
            key: _historyKey,
            repository: widget.repository,
            onOpenToday: () => setState(() => _tab = 0),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) {
          setState(() => _tab = i);
          if (i == 1) _historyKey.currentState?.reload();
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.edit_note_outlined),
            selectedIcon: Icon(Icons.edit_note),
            label: 'Log',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'History',
          ),
        ],
      ),
    );
  }
}
