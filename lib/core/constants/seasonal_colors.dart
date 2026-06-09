import 'package:flutter/material.dart';
import '../utils/solar_terms.dart';

class SeasonPalette {
  final Color deskBg;
  final Color deskBgDark;
  final Color paperWhite;
  final Color paperWhiteAlt;
  final Color goldAccent;
  final String decoration;
  final Color weatherIconBg;

  const SeasonPalette({
    required this.deskBg,
    required this.deskBgDark,
    required this.paperWhite,
    required this.paperWhiteAlt,
    required this.goldAccent,
    required this.decoration,
    required this.weatherIconBg,
  });

  SeasonPalette copyWith({
    Color? deskBg,
    Color? deskBgDark,
    Color? paperWhite,
    Color? paperWhiteAlt,
    Color? goldAccent,
    String? decoration,
    Color? weatherIconBg,
  }) {
    return SeasonPalette(
      deskBg: deskBg ?? this.deskBg,
      deskBgDark: deskBgDark ?? this.deskBgDark,
      paperWhite: paperWhite ?? this.paperWhite,
      paperWhiteAlt: paperWhiteAlt ?? this.paperWhiteAlt,
      goldAccent: goldAccent ?? this.goldAccent,
      decoration: decoration ?? this.decoration,
      weatherIconBg: weatherIconBg ?? this.weatherIconBg,
    );
  }
}

class SeasonalColors {
  SeasonalColors._();

  // 🌸 春季 — 柔粉嫩绿
  static const spring = SeasonPalette(
    deskBg: Color(0xFFE8DFD0),
    deskBgDark: Color(0xFFD8CFC0),
    paperWhite: Color(0xFFFFFBF5),
    paperWhiteAlt: Color(0xFFFFF8F0),
    goldAccent: Color(0xFFD4A0B0),
    decoration: 'lichun',
    weatherIconBg: Color(0x15FFB7C5),
  );

  // 🌿 夏季 — 明亮金橙
  static const summer = SeasonPalette(
    deskBg: Color(0xFFD8D0B8),
    deskBgDark: Color(0xFFC8C0A8),
    paperWhite: Color(0xFFFFFDF5),
    paperWhiteAlt: Color(0xFFFFFAE8),
    goldAccent: Color(0xFFE8A040),
    decoration: 'xiazhi',
    weatherIconBg: Color(0x15FFD54F),
  );

  // 🍂 秋季 — 暖红深金
  static const autumn = SeasonPalette(
    deskBg: Color(0xFFD8C8A8),
    deskBgDark: Color(0xFFC8B898),
    paperWhite: Color(0xFFFFF8F0),
    paperWhiteAlt: Color(0xFFFFF5E8),
    goldAccent: Color(0xFFC87040),
    decoration: 'qiufen',
    weatherIconBg: Color(0x15FF8A65),
  );

  // ❄️ 冬季 — 冷蓝银白
  static const winter = SeasonPalette(
    deskBg: Color(0xFFD0C8C0),
    deskBgDark: Color(0xFFC0B8B0),
    paperWhite: Color(0xFFF8F8FF),
    paperWhiteAlt: Color(0xFFF5F5FA),
    goldAccent: Color(0xFF8090A0),
    decoration: 'dongzhi',
    weatherIconBg: Color(0x1590CAF9),
  );

  /// Get palette for a season
  static SeasonPalette getPaletteForSeason(Season season) {
    switch (season) {
      case Season.spring:
        return spring;
      case Season.summer:
        return summer;
      case Season.autumn:
        return autumn;
      case Season.winter:
        return winter;
    }
  }
}
