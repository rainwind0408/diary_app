/// 悬浮球「该不该显示」的判定 —— **纯 Dart**，不依赖 Flutter，便于离线测试。
///
/// 判定输入是一个普通值对象，路由 / tab / 开关都从外面喂进来。
/// 这样这条规则可以在纯 Dart VM 里逐条断言 —— 它是「漏了也不报错」的那种逻辑，
/// 必须靠测试兜住（球出现在聊天页上不会崩，只是很怪）。
library;

/// 需要隐藏悬浮球的路由名。
///
/// ⚠️ 这些名字必须在 push 时显式传 `RouteSettings(name: ...)` 才有值。
/// 本项目现有代码一律是 `MaterialPageRoute(builder: (_) => const XxxScreen())`，
/// **没有传 settings**，所以 `route.settings.name` 全是 null ——
/// 名字对不上时悬浮球不会消失（null 不匹配任何排除项），也不会报错。
/// 这是一个静默失效的坑，改动 push 点时必须一起检查。
class OrbRoutes {
  OrbRoutes._();

  /// 主界面（`MainShell`）所在的那条路由。
  ///
  /// `MaterialApp.home` 生成的路由名固定是 `Navigator.defaultRouteName`（即 `'/'`），
  /// 所以「停在 MainShell 上」时 `topRouteName` 是 `'/'` 而**不是 null**。
  /// 判断「是不是在主界面上」必须把它算进去，否则「设置 tab 上不显示球」
  /// 这条规则永远命中不了。
  static const String home = '/';

  /// AI 聊天页本身（再飘一个球上去毫无意义）
  static const String chat = '/chat';

  /// 写日记画布：上面的图片/贴纸/录音都可拖拽，
  /// 球压在上面会造成「拖到一半被球接走手势」的困惑
  static const String write = '/write';

  /// AI 助手设置页：D1 说的「设置页」按语义覆盖所有设置类页面
  static const String aiSettings = '/ai-settings';

  static const Set<String> hidden = {chat, write, aiSettings};
}

/// 一次判定的全部输入
class OrbVisibilityInput {
  /// 设置里的「显示悬浮球」开关（D7：默认开）
  final bool enabled;

  /// 主界面（MainShell）是否已经挂上。
  /// 首次启动的欢迎页、以及启动前的 loading 期间为 false。
  final bool shellVisible;

  /// 栈顶是不是弹层（`PopupRoute`）。
  ///
  /// 这一条**天然覆盖所有弹层与全屏预览**：`showDialog` → `DialogRoute`、
  /// `showModalBottomSheet` → `ModalBottomSheetRoute`，两者都 `extends PopupRoute`。
  /// 不需要逐个列举。
  final bool topIsPopupRoute;

  /// 栈顶路由名（可能为 null —— 没传 `RouteSettings` 的页面就是 null）
  final String? topRouteName;

  /// 当前是否停在设置 tab（MainShell 的 IndexedStack index == 3）
  final bool onSettingsTab;

  const OrbVisibilityInput({
    required this.enabled,
    required this.shellVisible,
    required this.topIsPopupRoute,
    required this.topRouteName,
    required this.onSettingsTab,
  });
}

class OrbVisibility {
  OrbVisibility._();

  /// MainShell 里「设置」tab 的下标
  static const int settingsTabIndex = 3;

  static bool shouldShow(OrbVisibilityInput input) {
    if (!input.enabled) return false;
    if (!input.shellVisible) return false;

    // 弹层优先：它在任何页面之上，一律不显示
    if (input.topIsPopupRoute) return false;

    final name = input.topRouteName;
    if (name != null && OrbRoutes.hidden.contains(name)) return false;

    // 停在主界面上（`'/'`，或观察者还没收到 didPush 时的 null）
    // 且当前是设置 tab → 不显示
    final onMainShell = name == null || name == OrbRoutes.home;
    if (onMainShell && input.onSettingsTab) return false;

    return true;
  }
}
