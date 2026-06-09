import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/utils/solar_terms.dart';
import '../../../core/constants/seasonal_colors.dart';
import '../../../data/models/weather_data.dart';
import '../services/weather_service.dart';

class SeasonalProvider extends ChangeNotifier {
  static const _enabledKey = 'seasonal_theme_enabled';

  bool _isEnabled = true;
  Season _currentSeason = Season.spring;
  SolarTerm? _currentTerm;
  SolarTerm? _nextTerm;
  WeatherData? _weatherData;
  SeasonPalette _palette = SeasonalColors.spring;
  SeasonPalette _effectivePalette = SeasonalColors.spring;
  bool _isLoading = false;
  String? _lastTermName; // Track term changes for transition dialog
  String? _currentBackgroundPath;

  // Getters
  bool get isEnabled => _isEnabled;
  Season get currentSeason => _currentSeason;
  SolarTerm? get currentTerm => _currentTerm;
  SolarTerm? get nextTerm => _nextTerm;
  WeatherData? get weatherData => _weatherData;
  SeasonPalette get palette => _effectivePalette;
  bool get isLoading => _isLoading;
  String? get currentBackgroundPath => _currentBackgroundPath;

  /// Whether the season just changed (for showing transition dialog)
  bool get hasSeasonTransition {
    if (_currentTerm == null) return false;
    return _lastTermName != null && _lastTermName != _currentTerm!.name;
  }

  SeasonalProvider() {
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _isEnabled = prefs.getBool(_enabledKey) ?? true;

    // Always calculate season (pure computation, no network)
    _updateSeason();

    // Load weather if enabled
    if (_isEnabled) {
      await refreshWeather();
    }

    notifyListeners();
  }

  /// Update season based on current date
  void _updateSeason() {
    final now = DateTime.now();
    final previousTermName = _currentTerm?.name;
    _currentTerm = SolarTerms.getCurrentTerm(now);
    _nextTerm = SolarTerms.getNextTerm(now);
    _currentSeason = _currentTerm!.season;
    _lastTermName = previousTermName;

    _currentBackgroundPath = SolarTerms.getBackgroundPath(_currentTerm!.index);

    _palette = SeasonalColors.getPaletteForSeason(_currentSeason);
    _applyEffectivePalette();
  }

  /// Apply weather overlay to base palette
  void _applyEffectivePalette() {
    if (_weatherData != null && _isEnabled) {
      _effectivePalette = _applyWeatherOverlay(_palette, _weatherData!.category);
    } else {
      _effectivePalette = _palette;
    }
  }

  /// Weather affects subtle details on top of seasonal palette
  SeasonPalette _applyWeatherOverlay(SeasonPalette base, WeatherCategory weather) {
    switch (weather) {
      case WeatherCategory.rain:
      case WeatherCategory.drizzle:
        // 雨天效果已移除（原 ruledLine 字段已删除）
        return base;
      case WeatherCategory.snow:
        return base.copyWith(
          paperWhite: const Color(0xFFF5F5FF),
          paperWhiteAlt: const Color(0xFFF2F2FA),
        );
      case WeatherCategory.clear:
        return base.copyWith(
          goldAccent: Color.fromARGB(
            255,
            ((base.goldAccent.r * 255).round() + 10).clamp(0, 255),
            ((base.goldAccent.g * 255).round() + 5).clamp(0, 255),
            (base.goldAccent.b * 255).round(),
          ),
        );
      default:
        return base;
    }
  }

  /// Refresh weather data
  Future<void> refreshWeather() async {
    _isLoading = true;
    notifyListeners();

    try {
      _weatherData = await WeatherService.getWeatherWithFallback();
      _applyEffectivePalette();
    } catch (e) {
      // Weather fetch failed, keep existing data
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Toggle seasonal theme on/off
  Future<void> toggleEnabled() async {
    _isEnabled = !_isEnabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, _isEnabled);

    if (_isEnabled) {
      _updateSeason();
      await refreshWeather();
    } else {
      // Reset to default palette when disabled
      _effectivePalette = SeasonalColors.spring; // Will be overridden by AppColors defaults
    }

    notifyListeners();
  }

  /// Check and clear season transition flag (call after showing dialog)
  void clearSeasonTransition() {
    _lastTermName = _currentTerm?.name;
  }
}
