import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 字体缩放策略。
///
/// 用户手动选择 [scale]（0.8~1.4），由 `app.dart` 转成 `TextScaler.linear`
/// 应用到整棵 Widget 树。
///
/// 历史上还有一个「字体跟随系统」开关（直接吃系统 textScaler），
/// 2026-10-08 按用户要求整条移除 —— 只删 UI 会让已经存成 `true` 的老用户
/// 再也无法在界面上关掉它。
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
    _persistScale();
    notifyListeners();
  }

  Future<void> _persistScale() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_key, _scale);
  }
}
