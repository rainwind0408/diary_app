import 'package:flutter/foundation.dart';

/// 全局「日记数据变了」事件总线。
///
/// ## 为什么需要它
///
/// AI 的写工具（`DiaryMcpServer`）改的是数据库，而各个 Provider 的内存缓存
/// 不会自动更新 —— 用户切回日记列表会看到「AI 说写好了，但列表里没有」。
///
/// ## 为什么不用 provider / InheritedWidget
///
/// `DiaryMcpServer` 是纯数据层，拿不到 `BuildContext`，也不该反向依赖 UI 层。
/// 一个「版本号 + 监听」的极轻总线是这里唯一干净的做法。
class DiaryChangeBus {
  DiaryChangeBus._();

  /// 每次日记数据发生变化就 +1。
  ///
  /// 用**递增版本号**而不是「传递变更详情」：订阅方的动作一律是「整块重新加载」，
  /// 增量信息没人用，反而会诱使订阅方去做局部更新 —— 那种更新一旦和数据库
  /// 不一致，就会变成更难查的 bug。
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  /// 标记「日记数据已变」。写工具成功后调用。
  static void notifyChanged() => revision.value++;

  /// 订阅变更。
  ///
  /// 返回一个取消订阅的函数，方便 `State.dispose` 里直接调：
  /// ```dart
  /// late final void Function() _unsubscribe;
  /// void initState() { _unsubscribe = DiaryChangeBus.subscribe(_reload); }
  /// void dispose() { _unsubscribe(); }
  /// ```
  static void Function() subscribe(void Function() listener) {
    revision.addListener(listener);
    return () => revision.removeListener(listener);
  }
}
