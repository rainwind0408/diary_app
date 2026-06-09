import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';
import '../constants/seasonal_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme => buildLight(null);

  static ThemeData get darkTheme => buildDark(null);

  static ThemeData buildLight(SeasonPalette? seasonal) {
    // 水彩风格：使用粉色作为主色调
    final accent = seasonal?.goldAccent ?? AppColors.accentPink;
    final surface = seasonal?.paperWhite ?? AppColors.cardBackground;
    final scaffold = seasonal?.deskBg ?? AppColors.pageBackground;

    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: accent,
        brightness: Brightness.light,
        primary: accent,
        surface: surface,
      ),
      scaffoldBackgroundColor: scaffold,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
        ),
      ),
      fontFamily: 'ZCOOLXiaoWei',
      splashColor: accent.withValues(alpha: 0.1),
      highlightColor: accent.withValues(alpha: 0.05),
    );
  }

  static ThemeData buildDark(SeasonPalette? seasonal) {
    final accent = seasonal?.goldAccent.withValues(alpha: 0.9) ?? AppColors.darkAccentPink;

    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: accent,
        brightness: Brightness.dark,
        primary: accent,
        surface: AppColors.darkCardBackground,
      ),
      scaffoldBackgroundColor: AppColors.darkPageBackground,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
      ),
      fontFamily: 'ZCOOLXiaoWei',
      splashColor: accent.withValues(alpha: 0.1),
      highlightColor: accent.withValues(alpha: 0.05),
    );
  }
}
