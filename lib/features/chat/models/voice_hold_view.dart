/// 长按说话（语音输入）的状态与展示数据。
///
/// 刻意不引入任何 Flutter 依赖 —— 状态推导（提示语、剩余秒数）因此可以在
/// 纯 Dart VM 里直接单测，不必拉起 Widget 树。
library;

/// 长按说话浮层的三种状态。
enum VoiceHoldPhase {
  /// 正在听（手指还按着）
  listening,

  /// 手指上滑进了取消区，松手就作废
  canceling,

  /// 松手后正在转文字
  recognizing,
}

/// 浮层要展示的纯数据。
class VoiceHoldView {
  final VoiceHoldPhase phase;
  final int seconds;
  final int maxSeconds;

  const VoiceHoldView({
    required this.phase,
    this.seconds = 0,
    this.maxSeconds = 60,
  });

  bool get canceling => phase == VoiceHoldPhase.canceling;
  bool get recognizing => phase == VoiceHoldPhase.recognizing;

  /// 剩余秒数，到 0 时上层会自动收尾。
  int get remain {
    final left = maxSeconds - seconds;
    return left < 0 ? 0 : left;
  }

  String get hint {
    switch (phase) {
      case VoiceHoldPhase.listening:
        return '松手转成文字 · 上滑取消';
      case VoiceHoldPhase.canceling:
        return '松手取消';
      case VoiceHoldPhase.recognizing:
        return '正在转成文字…';
    }
  }
}
