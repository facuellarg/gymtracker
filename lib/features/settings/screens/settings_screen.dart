import 'package:flutter/material.dart';
import 'package:gymtracker/core/services/locale_prefs.dart';
import 'package:gymtracker/l10n/app_localizations.dart';

class SettingsScreen extends StatefulWidget {
  final String localeCode;
  final Future<void> Function(String code) onLocaleCodeChanged;

  const SettingsScreen({
    super.key,
    required this.localeCode,
    required this.onLocaleCodeChanged,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late String _localeCode = widget.localeCode;

  Future<void> _select(String? code) async {
    if (code == null || code == _localeCode) return;
    setState(() => _localeCode = code);
    await widget.onLocaleCodeChanged(code);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: RadioGroup<String>(
        groupValue: _localeCode,
        onChanged: _select,
        child: Column(
          children: [
            ListTile(title: Text(l10n.language)),
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
    );
  }
}
