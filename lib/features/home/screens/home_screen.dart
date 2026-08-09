import 'package:flutter/material.dart';
import 'package:gymtracker/features/history/screens/history_screen.dart';
import 'package:gymtracker/features/settings/screens/settings_screen.dart';
import 'package:gymtracker/features/workouts/repository/workout_repository.dart';
import 'package:gymtracker/features/workouts/screens/workout_screen.dart';
import 'package:gymtracker/l10n/app_localizations.dart';

class HomeScreen extends StatefulWidget {
  final WorkoutRepository repository;
  final String localeCode;
  final Future<void> Function(String code) onLocaleCodeChanged;

  const HomeScreen({
    super.key,
    required this.repository,
    required this.localeCode,
    required this.onLocaleCodeChanged,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;
  int _logGeneration = 0;
  final _historyKey = GlobalKey<HistoryScreenState>();

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => SettingsScreen(
          localeCode: widget.localeCode,
          onLocaleCodeChanged: widget.onLocaleCodeChanged,
          repository: widget.repository,
          onDataChanged: () {
            _refreshLog();
            _historyKey.currentState?.reload();
          },
        ),
      ),
    );
  }

  void _refreshLog() => setState(() => _logGeneration++);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: [
          WorkoutScreen(
            key: ValueKey(_logGeneration),
            repository: widget.repository,
          ),
          HistoryScreen(
            key: _historyKey,
            repository: widget.repository,
            onOpenToday: () => setState(() => _tab = 0),
            onOpenSettings: _openSettings,
            onTodayChanged: _refreshLog,
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) {
          setState(() => _tab = i);
          if (i == 1) _historyKey.currentState?.reload();
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.edit_note_outlined),
            selectedIcon: const Icon(Icons.edit_note),
            label: l10n.navLog,
          ),
          NavigationDestination(
            icon: const Icon(Icons.history_outlined),
            selectedIcon: const Icon(Icons.history),
            label: l10n.navHistory,
          ),
        ],
      ),
    );
  }
}
