import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymtracker/core/services/locale_prefs.dart';

void main() {
  test('localeFromCode maps system/en/es', () {
    expect(LocalePrefs.localeFromCode(LocalePrefs.system), isNull);
    expect(LocalePrefs.localeFromCode('unknown'), isNull);
    expect(LocalePrefs.localeFromCode('en'), const Locale('en'));
    expect(LocalePrefs.localeFromCode('es'), const Locale('es'));
  });
}
