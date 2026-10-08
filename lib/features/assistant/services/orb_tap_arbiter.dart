/// 悬浮球的单击 / 双击判定 —— **纯 Dart**，不依赖 Flutter，便于离线测试。
///
/// ## 为什么不用 Flutter 内置的 `onTap` + `onDoubleTap`
///
/// `DoubleTapGestureRecognizer` 在第一次抬手时会 `hold()` 住手势竞技场，
/// 逼 `onTap` 必须等到 `kDoubleTapTimeout`（**300ms**）才能回调 ——
/// 点一下悬浮球要愣 0.3 秒才打开聊天，手感很差。
///
/// 这里改成自己判：抬手时记时间，窗口内再来一次就是双击，否则等窗口到期
/// 执行单击。窗口取 200ms（比系统短），因为球的点击是低频操作，
/// 宁可偶尔把两次快点点成双击。
///
/// 调用方负责提供「现在几毫秒」（`DateTime.now().millisecondsSinceEpoch`），
/// 于是这个类不持有任何时钟，测试可以精确控制时间。
library;

enum OrbTapAction {
  /// 已经是一次双击（调用方应立即打开设置页）
  doubleTap,

  /// 这次抬手可能是单击，但还在等窗口到期 —— **不要做任何事**
  pending,
}

class OrbTapArbiter {
  OrbTapArbiter({this.windowMs = 200});

  /// 双击判定窗口。两次抬手的间隔**严格小于**这个值才算双击。
  final int windowMs;

  int? _lastTapMs;
  bool _pendingSingle = false;

  /// 有没有一次「待确认的单击」正等着窗口到期
  bool get hasPendingSingle => _pendingSingle;

  /// 收到一次抬手。
  ///
  /// - 返回 [OrbTapAction.doubleTap] → 双击成立，调用方打开设置页，
  ///   **并且要把之前挂起的单击定时器取消掉**（`hasPendingSingle` 已复位）。
  /// - 返回 [OrbTapAction.pending] → 调用方起一个 [windowMs] 的定时器，
  ///   到点时调 [resolvePending]。
  OrbTapAction registerTap(int nowMs) {
    final last = _lastTapMs;
    if (last != null && nowMs - last < windowMs) {
      _lastTapMs = null;
      _pendingSingle = false;
      return OrbTapAction.doubleTap;
    }
    _lastTapMs = nowMs;
    _pendingSingle = true;
    return OrbTapAction.pending;
  }

  /// 定时器到点时调用。
  ///
  /// 返回 true 表示「确实是一次单击」→ 打开聊天页；
  /// 返回 false 表示这次待定已经被双击或 [reset] 吃掉了，**什么都不要做**。
  bool resolvePending() {
    if (!_pendingSingle) return false;
    _pendingSingle = false;
    _lastTapMs = null;
    return true;
  }

  /// 清掉全部状态。
  ///
  /// 拖动结束、长按开始、页面不可见时都要调 —— 否则「拖完手一抖」
  /// 会和上一次点击凑成一次假双击，把设置页打开。
  void reset() {
    _lastTapMs = null;
    _pendingSingle = false;
  }
}
