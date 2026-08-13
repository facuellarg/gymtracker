import 'package:flutter/material.dart';

/// Notebook-leaning Material theme: muted ink seed, flat app bars, dense fields.
class AppTheme {
  // ponytail: single seed; split brand tokens if light/dark need different hues.
  static const seed = Color(0xFF3D5347);

  static ThemeData light() => _base(Brightness.light);
  static ThemeData dark() => _base(Brightness.dark);

  static ThemeData _base(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: brightness,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        scrolledUnderElevation: 0,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
      ),
      navigationBarTheme: NavigationBarThemeData(
        indicatorColor: scheme.secondaryContainer,
        backgroundColor: scheme.surface,
        elevation: 0,
        height: 64,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
          );
        }),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        isDense: true,
        border: OutlineInputBorder(),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: 0.5),
        space: 1,
        thickness: 1,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        subtitleTextStyle: TextStyle(
          color: scheme.onSurfaceVariant,
          fontSize: 14,
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          visualDensity: VisualDensity.standard,
        ),
      ),
    );
  }
}
