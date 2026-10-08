/// 悬浮球「语音直通」的纯逻辑 —— **不引入 Flutter**，可在纯 Dart VM 里单测。
///
/// 与聊天输入框的长按说话（`chat_input.dart`）有两点关键差异：
///
/// 1. **不经过输入框、不转文字确认** —— 识别出来直接发给 AI
///    （带上 `ReplyStyle.voiceBrief`：150 字以内 + 默认自动播报）。
/// 2. **原音频用完即删** —— 输入框那条链路依赖系统清理临时目录，
///    这条链路显式删，且**失败路径也删**。
library;

import 'dart:io';

/// 语音直通的判定与常量。
class VoiceDirectPolicy {
  VoiceDirectPolicy._();

  /// 一次长按说话的时长上限（秒），到点自动收尾。
  static const int maxHoldSeconds = 60;

  /// 手指上滑超过这个距离（逻辑像素）就进入「松手取消」。
  static const double cancelSlop = -80;

  /// 按得太短当作误触，不白跑一次识别请求。
  static const int minHoldMs = 600;

  /// 上滑位移是否已进入取消区。
  static bool cancelArmed(double offsetDy) => offsetDy < cancelSlop;

  /// 按住时长是否达到「值得识别」的下限。
  static bool longEnough(int heldMs) => heldMs >= minHoldMs;

  /// 已录秒数是否触顶（到顶就自动收尾，避免无限录）。
  static bool reachedCap(int seconds) => seconds >= maxHoldSeconds;

  /// 把秒数格式化成球下方的计时标签：`0:03` / `1:05`。
  static String formatSeconds(int seconds) {
    final s = seconds < 0 ? 0 : seconds;
    final m = s ~/ 60;
    final r = s % 60;
    return '$m:${r.toString().padLeft(2, '0')}';
  }
}

/// 删除临时录音文件。
///
/// **成功与失败路径都要调**（方案 D3：原音频不保存）——
/// 否则每次识别失败都会在临时目录里留下一个 WAV。
///
/// 清理失败一律吞掉：它不该影响主流程，也不该盖掉真正的错误提示。
Future<void> deleteTempAudio(String? path) async {
  if (path == null || path.isEmpty) return;
  try {
    final file = File(path);
    if (await file.exists()) await file.delete();
  } catch (_) {
    // 忽略：临时目录里的残留交给系统清理
  }
}

/// 把异常转成能直接给用户看的一句话。
///
/// 与 `chat_input.dart` 的同名逻辑保持一致：去掉 Dart 自动加的
/// `Exception: ` 前缀，其余原样透出（各家网关的错误正文本身就有用）。
String friendlyVoiceError(Object error) {
  final raw = error.toString();
  const prefix = 'Exception: ';
  return raw.startsWith(prefix) ? raw.substring(prefix.length) : raw;
}
