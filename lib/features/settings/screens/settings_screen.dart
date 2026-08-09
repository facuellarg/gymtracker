import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:gymtracker/core/services/locale_prefs.dart';
import 'package:gymtracker/core/services/workout_backup.dart';
import 'package:gymtracker/features/workouts/repository/workout_repository.dart';
import 'package:gymtracker/l10n/app_localizations.dart';

class SettingsScreen extends StatefulWidget {
  final String localeCode;
  final Future<void> Function(String code) onLocaleCodeChanged;
  final WorkoutRepository repository;
  final VoidCallback? onDataChanged;

  const SettingsScreen({
    super.key,
    required this.localeCode,
    required this.onLocaleCodeChanged,
    required this.repository,
    this.onDataChanged,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late String _localeCode = widget.localeCode;
  bool _busy = false;

  Future<void> _select(String? code) async {
    if (_busy || code == null || code == _localeCode) return;
    setState(() => _localeCode = code);
    await widget.onLocaleCodeChanged(code);
  }

  Future<void> _export() async {
    if (_busy) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() => _busy = true);
    try {
      final workouts = await widget.repository.getAll();
      final json = WorkoutBackup.encode(workouts);
      final stamp = DateTime.now().toIso8601String().split('T').first;
      final path = await FilePicker.saveFile(
        dialogTitle: l10n.exportWorkouts,
        fileName: 'gymtracker-backup-$stamp.json',
        type: FileType.custom,
        allowedExtensions: const ['json'],
        bytes: Uint8List.fromList(utf8.encode(json)),
      );
      if (path == null) return;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.exportDone)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.exportFailed('$e'))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    if (_busy) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() => _busy = true);
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['json'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      final file = result.files.single;
      final raw = file.bytes != null
          ? utf8.decode(file.bytes!)
          : await File(file.path!).readAsString();

      final workouts = WorkoutBackup.decode(raw);
      for (final w in workouts) {
        // Upsert by date: clear id so saveWorkout matches existing date.
        w.id = null;
        await widget.repository.saveWorkout(w);
      }
      widget.onDataChanged?.call();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.importDone(workouts.length))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.importFailed('$e'))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListView(
        children: [
          ListTile(title: Text(l10n.language)),
          RadioGroup<String>(
            groupValue: _localeCode,
            onChanged: _select,
            child: Column(
              children: [
                RadioListTile<String>(
                  title: Text(l10n.languageSystem),
                  value: LocalePrefs.system,
                ),
                RadioListTile<String>(
                  title: Text(l10n.languageEnglish),
                  value: 'en',
                ),
                RadioListTile<String>(
                  title: Text(l10n.languageSpanish),
                  value: 'es',
                ),
              ],
            ),
          ),
          const Divider(),
          ListTile(title: Text(l10n.backup)),
          ListTile(
            leading: const Icon(Icons.upload_outlined),
            title: Text(l10n.exportWorkouts),
            subtitle: Text(l10n.exportWorkoutsHint),
            enabled: !_busy,
            onTap: _export,
          ),
          ListTile(
            leading: const Icon(Icons.download_outlined),
            title: Text(l10n.importWorkouts),
            subtitle: Text(l10n.importWorkoutsHint),
            enabled: !_busy,
            onTap: _import,
          ),
          if (_busy)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
