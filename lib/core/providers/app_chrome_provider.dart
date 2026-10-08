import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 应用外壳（chrome）的全局状态：当前 tab、主界面是否已挂载、悬浮球开关。
///
/// 为什么需要一个 provider 而不是把状态塞进 `MainShell`：
/// 悬浮球挂在 `MaterialApp.builder` 那一层，是 `MainShell` 的**祖先的兄弟**，
/// 拿不到 `MainShell` 的 State，也拿不到它的 `BuildContext`。
/// 只能靠一个全局状态把「现在停在哪个 tab」传上去。
///
/// 刻意做得很轻：只有三个字段，变更频率极低（切 tab 才变）。
class AppChromeProvider extends ChangeNotifier {
  static const String _keyOrbEnabled = 'assistant_orb_enabled';

  /// 悬浮球是否启用（D7：默认开）
  static const bool defaultOrbEnabled = true;

  int _tabIndex = 0;
  bool _shellVisible = false;
  bool _orbEnabled = defaultOrbEnabled;
  bool _loaded = false;

  int get tabIndex => _tabIndex;

  /// 主界面（MainShell）是否已经挂上。
  ///
  /// 首次启动的欢迎页、启动前的 loading 期间都是 false —— 那时候不该有球。
  /// 一旦挂上就保持 true：`Navigator.push` 出来的页面会盖在 MainShell 之上，
  /// 但 MainShell 本身仍在树里（`maintainState` 默认 true），所以不会复位。
  bool get shellVisible => _shellVisible;

  bool get orbEnabled => _orbEnabled;

  /// 是否停在「设置」tab
  bool get onSettingsTab => _tabIndex == 3;

  /// 首选项是否已从磁盘读出。
  ///
  /// 没读完就先不渲染球 —— 否则用户把球关掉之后，每次冷启动都会看到它
  /// 闪一下再消失。
  bool get loaded => _loaded;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _orbEnabled = prefs.getBool(_keyOrbEnabled) ?? defaultOrbEnabled;
    } catch (_) {
      // 读不到就用默认值，不能让一个偏好设置把启动流程卡住
      _orbEnabled = defaultOrbEnabled;
    }
    _loaded = true;
    notifyListeners();
  }

  void setTabIndex(int index) {
    if (_tabIndex == index) return;
    _tabIndex = index;
    notifyListeners();
  }

  void setShellVisible(bool visible) {
    if (_shellVisible == visible) return;
    _shellVisible = visible;
    notifyListeners();
  }

  Future<void> setOrbEnabled(bool enabled) async {
    if (_orbEnabled == enabled) return;
    _orbEnabled = enabled;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyOrbEnabled, enabled);
    } catch (_) {
      // 写盘失败只影响下次启动，本次会话的行为已经生效
    }
  }
}
