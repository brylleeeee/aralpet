
import 'package:flutter/material.dart';

class GalaxyColors {
  static const Color background = Color(0xFF0B1020);
  static const Color surface = Color(0xFF19213B);
  static const Color surfaceLight = Color(0xFF252E4D);

  static const Color purple = Color(0xFFA78BFA);
  static const Color blue = Color(0xFF38BDF8);
  static const Color pink = Color(0xFFF472B6);
  static const Color gold = Color(0xFFFBBF24);
  static const Color mint = Color(0xFF34D399);

  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFFA9B7D1);
  static const Color border = Color(0xFF414B70);
}

class AppTheme {
  // Retained for compatibility with existing widgets.
  static const Color seed = GalaxyColors.purple;

  static ThemeData get dark {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: GalaxyColors.purple,
      brightness: Brightness.dark,
    ).copyWith(
      primary: GalaxyColors.purple,
      onPrimary: GalaxyColors.background,
      secondary: GalaxyColors.blue,
      surface: GalaxyColors.surface,
      onSurface: GalaxyColors.textPrimary,
      error: const Color(0xFFFF6B82),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: GalaxyColors.background,
      canvasColor: GalaxyColors.background,
      dividerColor: GalaxyColors.border,

      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: GalaxyColors.textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 21,
          fontWeight: FontWeight.bold,
          color: GalaxyColors.textPrimary,
        ),
      ),

      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.bold,
          color: GalaxyColors.textPrimary,
        ),
        headlineMedium: TextStyle(
          fontSize: 25,
          fontWeight: FontWeight.bold,
          color: GalaxyColors.textPrimary,
        ),
        titleLarge: TextStyle(
          fontSize: 21,
          fontWeight: FontWeight.w700,
          color: GalaxyColors.textPrimary,
        ),
        titleMedium: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: GalaxyColors.textPrimary,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          color: GalaxyColors.textPrimary,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          color: GalaxyColors.textSecondary,
        ),
      ),

      cardTheme: CardThemeData(
        color: GalaxyColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(
            color: GalaxyColors.border,
            width: 0.7,
          ),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: GalaxyColors.surface,
        labelStyle: const TextStyle(
          color: GalaxyColors.textSecondary,
        ),
        hintStyle: const TextStyle(
          color: GalaxyColors.textSecondary,
        ),
        prefixIconColor: GalaxyColors.purple,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: GalaxyColors.border,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: GalaxyColors.purple,
            width: 1.6,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: GalaxyColors.purple,
          foregroundColor: GalaxyColors.background,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: GalaxyColors.purple,
          foregroundColor: GalaxyColors.background,
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: GalaxyColors.purple,
          side: const BorderSide(
            color: GalaxyColors.border,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),

      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: GalaxyColors.purple,
        foregroundColor: GalaxyColors.background,
      ),

      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: GalaxyColors.surface,
        selectedItemColor: GalaxyColors.purple,
        unselectedItemColor: GalaxyColors.textSecondary,
        type: BottomNavigationBarType.fixed,
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: GalaxyColors.surface,
        indicatorColor: GalaxyColors.purple.withValues(alpha: 0.20),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 12,
            color: states.contains(WidgetState.selected)
                ? GalaxyColors.purple
                : GalaxyColors.textSecondary,
          ),
        ),
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: GalaxyColors.purple,
        linearTrackColor: GalaxyColors.surfaceLight,
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: GalaxyColors.surfaceLight,
        contentTextStyle: const TextStyle(
          color: GalaxyColors.textPrimary,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Keep this temporarily so existing code using AppTheme.light
  // continues to compile. Both getters now use the galaxy theme.
  static ThemeData get light => dark;
}
