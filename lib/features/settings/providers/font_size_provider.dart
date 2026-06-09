import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FontSizeProvider extends ChangeNotifier {
  static const _key = 'font_size_scale';
  static const double minScale = 0.8;
  static const double maxScale = 1.4;

  double _scale = 1.0;
  double get scale => _scale;

  FontSizeProvider() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _scale = prefs.getDouble(_key) ?? 1.0;
    notifyListeners();
  }

  void setScale(double value) {
    _scale = value.clamp(minScale, maxScale);
    _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_key, _scale);
  }
}
