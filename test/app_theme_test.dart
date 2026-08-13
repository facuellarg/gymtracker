import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymtracker/core/theme/app_theme.dart';

void main() {
  test('AppTheme light/dark use ink seed and dense inputs', () {
    final light = AppTheme.light();
    final dark = AppTheme.dark();

    expect(light.colorScheme.brightness, Brightness.light);
    expect(dark.colorScheme.brightness, Brightness.dark);
    expect(light.colorScheme.primary.toARGB32() != 0, isTrue);
    expect(
      light.inputDecorationTheme.isDense,
      isTrue,
      reason: 'History search + dialogs share dense outline fields',
    );
    expect(light.appBarTheme.scrolledUnderElevation, 0);
    expect(dark.appBarTheme.scrolledUnderElevation, 0);
  });
}
