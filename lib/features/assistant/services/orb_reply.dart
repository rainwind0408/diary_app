/// 悬浮球「语音直通」**回复气泡**的纯逻辑 —— **不引入 Flutter**，可在纯 Dart VM 里单测。
///
/// 与 [VoiceDirectPolicy]（录音阶段）分工：
/// - `voice_direct.dart` 管「按住 → 松手 → 转文字」；
/// - 本文件管「文字已发给 AI → 回复显示 → 自动消失」。
///
/// ## 需求来源（用户拍板，勿擅自改）
/// 1. 气泡在**显示完全部文字之后**再驻留 5 秒自动消失；
/// 2. 点气泡外任意位置也能提前关掉（**AI 助手图标本身除外**）；
/// 3. 点气泡本身**不打开聊天页**（只是看着）；
/// 4. 尾巴做成**圆弧**（不是尖角三角）。
library;

/// 气泡的阶段。
enum OrbReplyPhase {
  /// 不显示（空闲）
  hidden,

  /// 用户的话已发出，一个字都还没回来
  waiting,

  /// 正在逐字流式输出
  streaming,

  /// 回复完成，气泡驻留中（等 5 秒自动消失）
  done,

  /// 出错（显示错误文案）
  failed,
}

/// 气泡要显示的内容。**只放正文，永不放思考过程**。
///
/// 「不显示思考」就是靠这里实现的 —— `reasoning` 在这条链路上从头到尾
/// 没有被读取过，因此不需要任何开关。
class OrbReply {
  final OrbReplyPhase phase;

  /// 正文（`streaming` / `done` 时是已到达的文本；`failed` 时是错误文案）
  final String text;

  const OrbReply({this.phase = OrbReplyPhase.hidden, this.text = ''});

  static const OrbReply hidden = OrbReply();

  /// 气泡此刻是否应该在屏幕上
  bool get visible => phase != OrbReplyPhase.hidden;

  /// 是否还在等回复（还没定稿）—— 这个阶段**不启动**自动消失计时
  bool get pending =>
      phase == OrbReplyPhase.waiting || phase == OrbReplyPhase.streaming;

  /// 真正要渲染的文案（`waiting` 阶段没有正文，显示占位）
  String get display {
    switch (phase) {
      case OrbReplyPhase.hidden:
        return '';
      case OrbReplyPhase.waiting:
        return '正在想…';
      case OrbReplyPhase.streaming:
      case OrbReplyPhase.done:
        return text;
      case OrbReplyPhase.failed:
        return text.isEmpty ? '出了点问题，再试一次？' : text;
    }
  }

  @override
  String toString() => 'OrbReply($phase, ${text.length}字)';
}

/// 气泡的几何与时长常量。
class OrbReplyPolicy {
  OrbReplyPolicy._();

  /// ★ 全部文字显示完之后，气泡再驻留多久（用户拍板：5 秒）。
  static const Duration dwell = Duration(seconds: 5);

  /// 气泡正文区宽度上限（不含尾巴）。
  ///
  /// `voiceBrief` 要求模型 150 字以内，300 逻辑像素大约每行 16 个汉字，
  /// 150 字 ≈ 10 行 ≈ 220px 高，仍在 [maxHeightRatio] 之内。
  static const double maxWidth = 300;

  /// 气泡高度上限 = 屏高 × 该比例。
  static const double maxHeightRatio = 0.45;

  /// 圆弧尾巴从气泡主体伸出去的长度。
  static const double tailLength = 10;

  /// 圆弧尾巴根部的高度的一半。
  static const double tailHalfHeight = 8.5;

  /// 尾巴中心线在气泡内的高度（**相对气泡自身顶部**）。
  ///
  /// 固定值而不是「气泡垂直居中」：短气泡看起来像常规气泡，
  /// 长气泡的尾巴自然落在靠上的位置 —— 和 QQ / 微信气泡的观感一致，
  /// 而且**不需要先量出气泡高度**再定位（避开「居中要高度、高度要布局」的循环）。
  static const double tailY = 24;

  /// 气泡圆角
  static const double radius = 14;

  /// 正文内边距（尾巴那一侧会额外加上 [tailLength]）
  static const double contentPadding = 14;

  /// 上下内边距
  static const double verticalPadding = 10;

  /// 气泡离屏幕边缘的最小距离
  static const double screenMargin = 12;

  /// 气泡最小高度。
  ///
  /// **不能小于 `tailY + tailHalfHeight + radius`**，否则尾巴会撞进
  /// 主体左下/右下的圆角里，接缝处会出现一个别扭的凹口。
  static const double minHeight = tailY + tailHalfHeight + radius + 1;

  /// 气泡最大宽度下界（球贴边时可用空间可能很小，但再小也得能读）
  static const double minWidth = 120;
}
