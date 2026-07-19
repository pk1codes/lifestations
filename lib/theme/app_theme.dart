import 'package:flutter/material.dart';

abstract final class AppColors {
  static const rose = Color(0xFF9B3B5A);
  static const deepRose = Color(0xFF7A2E48);
  static const amber = Color(0xFFD4A373);
  static const cream = Color(0xFFFFF8F3);
  static const darkCream = Color(0xFFF5E6DC);
  static const ink = Color(0xFF2C1E22);
  static const muted = Color(0xFF6B555C);
  static const surface = Color(0xFFFFFBFA);
  static const whatsapp = Color(0xFF25D366);
}

ThemeData buildTheme() {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: AppColors.rose,
        brightness: Brightness.light,
        surface: AppColors.surface,
      ).copyWith(
        primary: AppColors.rose,
        secondary: AppColors.amber,
        onSurface: AppColors.ink,
      );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.cream,
  );
  return base.copyWith(
    textTheme: base.textTheme.copyWith(
      displaySmall: base.textTheme.displaySmall?.copyWith(
        fontFamily: 'Georgia',
        color: AppColors.ink,
        fontWeight: FontWeight.w600,
      ),
      headlineMedium: base.textTheme.headlineMedium?.copyWith(
        fontFamily: 'Georgia',
        color: AppColors.ink,
        fontWeight: FontWeight.w600,
      ),
      titleLarge: base.textTheme.titleLarge?.copyWith(
        fontFamily: 'Georgia',
        color: AppColors.ink,
        fontWeight: FontWeight.w600,
      ),
    ),
    cardTheme: const CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
        borderSide: BorderSide.none,
      ),
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      indicatorColor: AppColors.darkCream,
      height: 72,
    ),
  );
}
