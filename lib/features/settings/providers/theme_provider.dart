import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  static const _key = 'theme_mode';

  ThemeMode _mode = ThemeMode.light;
  ThemeMode get mode => _mode;

  bool get isDark => _mode == ThemeMode.dark;

  ThemeProvider() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    if (saved == 'dark') {
      _mode = ThemeMode.dark;
      notifyListeners();
    }
  }

  void toggle() {
    _mode = _mode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    _persist();
    notifyListeners();
  }

  void setMode(ThemeMode mode) {
    _mode = mode;
    _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, _mode == ThemeMode.dark ? 'dark' : 'light');
  }
}
