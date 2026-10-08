import 'package:flutter/material.dart';

/// 记录「栈顶是哪条路由」，供悬浮球判断该不该显示。
///
/// 悬浮球挂在 `MaterialApp.builder` 里，位置在 Navigator **之上**，
/// 所以它盖在所有路由上面 —— 包括 `showDialog` / `showModalBottomSheet`
/// 弹出来的弹层。这不是我们想要的（确认卡片、生图弹层被一个球压住很怪），
/// 于是需要知道当前栈顶是什么。
///
/// 用 `ValueNotifier` 而不是 `ChangeNotifier`：订阅方（悬浮球）只关心
/// 「路由变了」这一件事，用 `ValueListenableBuilder` 可以直接把重建范围
/// 限制在球自己身上，不会波及整棵树。
class AssistantRouteObserver extends NavigatorObserver {
  AssistantRouteObserver();

  /// 当前栈顶路由；null = 还没有任何路由（或已全部弹出）
  static final ValueNotifier<Route<dynamic>?> topRoute =
      ValueNotifier<Route<dynamic>?>(null);

  static void _set(Route<dynamic>? route) {
    // 只在「名字变了」或「类型变了」时才通知 —— 否则同一条路由的
    // 内部替换（例如 ModalBottomSheet 的动画重建）会白白触发重建
    final prev = topRoute.value;
    if (identical(prev, route)) return;
    topRoute.value = route;
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _set(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _set(previousRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _set(previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _set(newRoute);
  }
}
