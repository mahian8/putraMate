import 'package:flutter/material.dart';

class AppTheme {
  static const Color seed = Color(0xFFE53935); // Red seed color

  static ThemeData light() {
    final base = ThemeData(useMaterial3: true, colorSchemeSeed: seed);
    final scheme = base.colorScheme.copyWith(primary: seed, secondary: seed);
    return base.copyWith(
      colorScheme: scheme,
      appBarTheme: AppBarTheme(
        backgroundColor: seed,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 1,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: seed,
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: seed,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.primaryContainer.withValues(alpha: 0.1),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.primary.withValues(alpha: 0.4)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: seed, width: 1.5),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: scheme.primaryContainer,
        selectedColor: seed,
        labelStyle: TextStyle(color: scheme.onPrimaryContainer),
      ),
      cardTheme: CardThemeData(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
    );
  }
}
