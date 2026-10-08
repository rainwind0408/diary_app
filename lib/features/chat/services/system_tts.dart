import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'tts_codec.dart';

/// 系统自带语音朗读（Android 标准 `TextToSpeech`）。
///
/// ## 它和 `LocalTtsEngine` 的区别
/// - `LocalTtsEngine` 跑**下载到手机里**的 sherpa-onnx 模型，**返回音频字节**；
/// - 这里借用**手机里已有的 TTS 引擎**，**边合成边播、拿不到字节**。
///
/// 所以它不走 `TtsClient` 的「合成 → 拿字节」链路，而是在 [TtsPlayer] 里
/// 被单独分流：直接把文字交给引擎，播完由引擎回调通知。
/// 依赖音频字节的功能（导出音频）对系统语音必须显式禁用。
///
/// ## 为什么这是「零权限」的
/// 系统 TTS 引擎（本机实测 `com.huawei.hiai` 的 `TtsSystemService`）是
/// `exported=true` 且 **`permission=null`** 的 —— 标准 API 直接就能调，
/// 不需要任何运行时授权，也不需要厂商专属代码。
///
/// ## ⚠️ 前置条件（漏了会静默失败）
/// `AndroidManifest.xml` 必须声明：
/// ```xml
/// <queries>
///   <intent><action android:name="android.intent.action.TTS_SERVICE"/></intent>
/// </queries>
/// ```
/// API 30+ 的**包可见性**机制会让 App 看不见 TTS 引擎，绑定失败时报的是
/// `speak failed: not bound to TTS engine` —— 完全看不出是清单问题。
///
/// ## ⚠️ 不要自己枚举引擎
/// 设备上可能有第三方 App 塞进来的垃圾引擎（本机就有一个腾讯视频的
/// `AndroidTTSService`，`enabled=false`）。**永远用系统默认引擎**，
/// 让 `TextToSpeech` 自己选。
class SystemTts {
  SystemTts._();

  /// 默认语言。**必须是 locale 标签**（`zh-CN`），不是音色名 ——
  /// 各家系统引擎的音色命名完全不统一，第三方拿不到一致的「音色」概念。
  ///
  /// 常量本体在 `tts_codec.dart`（那边要保持纯 Dart，不能反向依赖本文件）。
  static const String defaultLocale = systemDefaultLocale;

  static FlutterTts? _tts;

  /// 当前是否正在朗读（含引擎排队中）
  static bool _speaking = false;

  static bool get isSpeaking => _speaking;

  /// 朗读结束 / 出错时的回调，由 [TtsPlayer] 注入用来复位全局状态
  static VoidCallback? _onDone;

  static FlutterTts _ensure() {
    final existing = _tts;
    if (existing != null) return existing;

    final tts = FlutterTts();
    // 不等待播完：speak() 必须立刻返回，否则 TtsPlayer 的 finally 会一直挂着，
    // 「正在合成」的转圈永远不消失。
    tts.awaitSpeakCompletion(false);
    tts.setStartHandler(() => _speaking = true);
    tts.setCompletionHandler(_finish);
    tts.setCancelHandler(_finish);
    tts.setErrorHandler((_) => _finish());
    _tts = tts;
    return tts;
  }

  /// 引擎报告「这一条结束了」。
  ///
  /// [_speaking] 兼作**重入守卫**：[stop] 会先把标志位落下来，
  /// 于是引擎随后回调的 cancel / completion 会在这里直接早退，
  /// 不会又绕回去调一遍 [stop]（那是死循环）。
  static void _finish() {
    if (!_speaking) return;
    _speaking = false;
    final cb = _onDone;
    _onDone = null;
    cb?.call();
  }

  /// 把配置里的「倍数」换算成 `flutter_tts` 的语速刻度。
  ///
  /// ⚠️ **两个刻度不是一回事，差 2 倍**：
  /// - 本项目的 `ttsSpeed` 与云端厂商（OpenAI `speed` / DashScope）都是
  ///   **1.0 = 正常语速**；
  /// - `flutter_tts` 的 Dart 刻度是 **0.5 = 正常语速**（0.0 最慢、1.0 最快）。
  ///   插件源码可查：Android 侧 `setSpeechRate(rate * 2.0f)`（注释原话
  ///   「Android 1.0 is mapped to flutter 0.5」），iOS 侧直接赋给
  ///   `AVSpeechUtterance.rate`（`AVSpeechUtteranceDefaultSpeechRate == 0.5`）——
  ///   **两端都是 0.5 = 正常**，所以这里必须 `× 0.5`。
  ///
  /// 不换算的后果：配置里写 1.0× 会实播成 **2 倍速**（Android）/ **最快**（iOS）。
  static double toFlutterRate(double speed) => (speed * 0.5).clamp(0.0, 1.0);

  /// 手机里到底有没有可用的 TTS 引擎，且它认中文。
  ///
  /// ⚠️ 整段包在 try 里：**没装任何引擎的机器上，`isLanguageAvailable`
  /// 本身就可能抛**（而不是返回 false）。任何异常都当「不可用」，
  /// 让上层去回落，不要把异常抛给用户。
  ///
  /// ⚠️ 但**不能静默吞异常**：曾经因为插件没被注册（`MissingPluginException`）
  /// 而被这里吞掉，对外表现成「这台手机没有语音引擎」，把**构建期问题
  /// 伪装成了设备能力问题**，排查方向全错。所以至少 `debugPrint` 出来。
  static Future<bool> isAvailable() async {
    try {
      final ok = await _ensure().isLanguageAvailable(defaultLocale);
      return ok == true;
    } catch (e, st) {
      debugPrint('[SystemTts] isLanguageAvailable 调用失败：$e\n$st');
      return false;
    }
  }

  /// 直接朗读。[onDone] 在播完（或出错 / 被停）时回调一次。
  ///
  /// [speed] 与配置里的 `ttsSpeed` 同一刻度（**1.0 = 正常语速**）——
  /// 内部会经 [toFlutterRate] 换算成 `flutter_tts` 的刻度，别在这里再乘。
  static Future<void> speak({
    required String text,
    required double speed,
    String voice = '',
    VoidCallback? onDone,
  }) async {
    final body = text.trim();
    if (body.isEmpty) return;

    final tts = _ensure();
    _onDone = onDone;

    // 音色对系统语音来说就是**语言标签**（`zh-CN` / `en-US`），留空取默认。
    final locale = voice.trim().isEmpty ? defaultLocale : voice.trim();
    await tts.setLanguage(locale);
    // ⚠️ 必须换算：配置 1.0 = 正常，而插件 0.5 = 正常（见 toFlutterRate）
    await tts.setSpeechRate(toFlutterRate(speed));
    await tts.setVolume(1.0);
    await tts.setPitch(1.0);

    _speaking = true;
    await tts.speak(body);
  }

  /// 停止朗读。重复调用安全。
  static Future<void> stop() async {
    _speaking = false;
    _onDone = null;
    try {
      await _tts?.stop();
    } catch (_) {
      // 引擎可能还没初始化，无所谓
    }
  }
}
