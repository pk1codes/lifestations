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

/// Shared ink strengths — obvious press feedback for low-literacy users.
abstract final class AppTapFeedback {
  static final splash = AppColors.rose.withValues(alpha: 0.32);
  static final highlight = AppColors.amber.withValues(alpha: 0.22);
  static final overlayPressed = AppColors.rose.withValues(alpha: 0.24);
  static final overlayHovered = AppColors.rose.withValues(alpha: 0.10);
  static final overlayFocused = AppColors.rose.withValues(alpha: 0.14);

  static WidgetStateProperty<Color?> overlayColor() {
    return WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.pressed)) return overlayPressed;
      if (states.contains(WidgetState.hovered)) return overlayHovered;
      if (states.contains(WidgetState.focused)) return overlayFocused;
      return null;
    });
  }
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
    splashFactory: InkRipple.splashFactory,
    splashColor: AppTapFeedback.splash,
    highlightColor: AppTapFeedback.highlight,
    materialTapTargetSize: MaterialTapTargetSize.padded,
  );
  final overlay = AppTapFeedback.overlayColor();
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
    iconButtonTheme: IconButtonThemeData(
      style: ButtonStyle(overlayColor: overlay),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 48),
      ).copyWith(overlayColor: overlay),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 48),
      ).copyWith(overlayColor: overlay),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
      ).copyWith(overlayColor: overlay),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(48, 48),
      ).copyWith(overlayColor: overlay),
    ),
    chipTheme: base.chipTheme.copyWith(
      pressElevation: 0,
      selectedColor: AppColors.darkCream,
      secondarySelectedColor: AppColors.darkCream,
      backgroundColor: AppColors.surface,
      side: const BorderSide(color: AppColors.darkCream),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: AppColors.rose,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      enableFeedback: true,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      indicatorColor: AppColors.darkCream,
      height: 72,
      overlayColor: overlay,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontSize: 12,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? AppColors.rose : AppColors.muted,
        );
      }),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: AppColors.rose,
      foregroundColor: Colors.white,
      splashColor: AppTapFeedback.splash,
      enableFeedback: true,
    ),
  );
}
