import 'package:flutter/material.dart';

/// App-wide color constants
class AppColors {
  AppColors._();

  // Primary backgrounds
  static const Color scaffoldBackground = Color(0xFF1A1A2E);
  static const Color drawerBackground = Color(0xFF16213E);
  static const Color cardBackground = Color(0xFF0D0D1A);
  static const Color surfaceColor = Color(0xFF1E1E2C);

  // Accent colors
  static const Color primaryAccent = Colors.greenAccent;
  static const Color warningAccent = Colors.amber;
  static const Color errorAccent = Colors.redAccent;

  // Tuning indicator colors
  static const Color inTuneColor = Colors.greenAccent;
  static const Color closeColor = Colors.yellowAccent;
  static const Color outOfTuneColor = Colors.redAccent;
  static const Color standbyColor = Color(0xFF64B5F6);

  // Text colors
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Colors.white70;
  static const Color textMuted = Colors.white38;
  static const Color textDisabled = Colors.white24;

  // Wood colors for headstock
  static const Color woodLight = Color(0xFF5D4037);
  static const Color woodDark = Color(0xFF3E2723);
}

/// App-wide theme configuration
class AppTheme {
  AppTheme._();

  static ThemeData get darkTheme {
    return ThemeData.dark().copyWith(
      scaffoldBackgroundColor: AppColors.scaffoldBackground,
      drawerTheme: const DrawerThemeData(
        backgroundColor: AppColors.drawerBackground,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: AppColors.textSecondary,
          fontSize: 18,
          fontFamily: 'Roboto',
        ),
        iconTheme: IconThemeData(color: AppColors.textSecondary),
      ),
      textTheme: const TextTheme(bodyMedium: TextStyle(fontFamily: 'Roboto')),
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primaryAccent,
        secondary: AppColors.primaryAccent,
        surface: AppColors.surfaceColor,
      ),
    );
  }
}
