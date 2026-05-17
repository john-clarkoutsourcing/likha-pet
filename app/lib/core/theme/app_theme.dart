import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData get dark {
    const baseTextTheme = TextTheme(
      headlineLarge: TextStyle(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w800,
        fontSize: 28,
        letterSpacing: 0.5,
      ),
      headlineMedium: TextStyle(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w700,
        fontSize: 22,
      ),
      titleMedium: TextStyle(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w600,
        fontSize: 16,
      ),
      bodyMedium: TextStyle(
        color: AppColors.textSecondary,
        fontSize: 14,
      ),
      labelSmall: TextStyle(
        color: AppColors.textMuted,
        fontSize: 11,
        letterSpacing: 0.8,
      ),
    );

    final themedText = baseTextTheme.apply(fontFamily: 'Fredoka').copyWith(
      headlineLarge: baseTextTheme.headlineLarge?.copyWith(fontFamily: 'LilitaOne'),
      headlineMedium: baseTextTheme.headlineMedium?.copyWith(fontFamily: 'LilitaOne'),
      titleMedium: baseTextTheme.titleMedium?.copyWith(fontFamily: 'LilitaOne'),
      labelSmall: baseTextTheme.labelSmall?.copyWith(fontFamily: 'LilitaOne'),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: 'Fredoka',
      scaffoldBackgroundColor: AppColors.bg,
      colorScheme: const ColorScheme.dark(
        primary:   AppColors.primary,
        secondary: AppColors.secondary,
        surface:   AppColors.surface,
        error:     Color(0xFFCF6679),
      ),
      cardTheme: const CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
      textTheme: themedText,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textPrimary,
          minimumSize: const Size(44, 44),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
      ),
    );
  }
}
