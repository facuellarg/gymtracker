import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists language override: absent/`system` → follow device; `en`/`es` → force.
class LocalePrefs {
  static const key = 'localeOverride';
  static const system = 'system';

  static Future<String> loadCode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key) ?? system;
  }

  static Future<void> saveCode(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, code);
  }

  /// Maps stored preference to MaterialApp.locale (null = device).
  static Locale? localeFromCode(String code) {
    return switch (code) {
      'en' => const Locale('en'),
      'es' => const Locale('es'),
      _ => null,
    };
  }
}
