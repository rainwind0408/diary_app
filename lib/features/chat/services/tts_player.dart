import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/ai_provider.dart';
import 'ai_config_store.dart';
import 'local_model_store.dart';
import 'system_tts.dart';
import 'tts_client.dart';
import 'tts_codec.dart';

/// 语音朗读播放器（Flutter 侧）。
///
/// 只做三件事：合成 → 写临时文件 → 播放，外加「当前在念哪条消息」这个全局状态。
/// 网络与协议解析都在 [TtsClient] / [tts_codec] 里（纯 Dart，可离线测），这里不碰。
///
/// 用静态单例而不是 provider：朗读是**全局唯一**的资源（同一时刻只能有一条在念），
/// 放进某个页面的 State 里，切页就会漏掉正在播的音频。
class TtsPlayer {
  TtsPlayer._();

  static final AudioPlayer _player = AudioPlayer();

  /// 正在朗读（含合成中）的消息 id；null = 空闲
  static final ValueNotifier<int?> speakingId = ValueNotifier<int?>(null);

  /// 是否还在合成（已点朗读但音频还没开始播）
  static final ValueNotifier<bool> synthesizing = ValueNotifier<bool>(false);

  static StreamSubscription<void>? _completeSub;

  /// 最后一次失败的原因，供界面提示；成功后清空
  static String? lastError;

  /// 有没有正在合成 / 播放
  static bool get isBusy => speakingId.value != null;

  /// 朗读一条消息（[markdown] 是气泡里的原文，会先洗成适合念的文本）。
  ///
  /// 失败**不抛异常** —— 调用方多半是按钮回调，抛出去只会变成一个红屏。
  /// 原因写进 [lastError]，由界面读走。
  static Future<void> speak({
    required int messageId,
    required String markdown,
  }) async {
    await stop();

    final text = truncateForSpeech(speechTextOf(markdown));
    if (text.isEmpty) {
      lastError = '这条消息没有可朗读的文字';
      return;
    }

    final config = await AiConfigStore.load();
    final blocked = _blockReason(config.activeProvider(AiCapability.tts));
    if (blocked != null) {
      lastError = blocked;
      return;
    }
    final provider = config.activeProvider(AiCapability.tts)!;

    speakingId.value = messageId;
    synthesizing.value = true;
    try {
      // ── 系统自带语音：不走「合成 → 落临时文件 → AudioPlayer」这条链路 ──
      //
      // 它是**边合成边播**的，拿不到音频字节，所以只能直接交给引擎。
      // 播完由引擎回调 [SystemTts] → 再回到这里 [stop] 复位全局状态。
      if (provider.protocol == AiProtocol.system) {
        if (!await SystemTts.isAvailable()) {
          lastError = '这台手机没有可用的系统语音引擎（或没装中文语音包）。'
              '请到「AI 助手设置 → 语音合成」里改用「本地模型」或云端厂商';
          await stop();
          return;
        }
        await SystemTts.speak(
          text: text,
          speed: config.ttsSpeed,
          // 对系统语音来说这个字段是**语言标签**（`zh-CN`），不是音色名
          voice: config.ttsVoice,
          // 念完自动复位，不然图标会一直停在「停止」上
          onDone: () {
            stop();
          },
        );
        lastError = null;
        return;
      }

      final audio = await TtsClient.synthesize(
        provider: provider,
        model: config.activeModel(AiCapability.tts) ?? '',
        text: text,
        voice: config.ttsVoice,
        speed: config.ttsSpeed,
        // 选中的是本地模型时给出它的目录；否则为 null（云端链路不用）
        localModelDir: await LocalModelStore.dirForProvider(provider),
      );

      final file = await _writeTemp(messageId, audio);
      await _player.setSource(DeviceFileSource(file.path));

      await _completeSub?.cancel();
      _completeSub = _player.onPlayerComplete.listen((_) {
        // 念完自动复位，不然图标会一直停在「停止」上
        stop();
      });

      await _player.resume();
      lastError = null;
    } catch (e) {
      lastError = _readable(e);
      await stop();
    } finally {
      synthesizing.value = false;
    }
  }

  /// 停止朗读并复位状态（重复调用是安全的）
  static Future<void> stop() async {
    // 系统语音不经过 AudioPlayer，得单独停。
    // 注意 [SystemTts.stop] 内部先把「正在播」的标志位落下来，
    // 所以引擎随后回调的 cancel / completion 不会再绕回来重入这里。
    await SystemTts.stop();
    try {
      await _player.stop();
    } catch (_) {
      // 播放器可能还没初始化，无所谓
    }
    await _completeSub?.cancel();
    _completeSub = null;
    synthesizing.value = false;
    if (speakingId.value != null) speakingId.value = null;
  }

  /// 配置缺什么 —— 三种「还没配好」的文案只写这一处
  static String? _blockReason(AiProvider? provider) {
    if (provider == null) {
      return '还没有配置语音合成厂商，请到「AI 助手设置 → 语音合成」里添加';
    }
    // 本地离线模型没有 Key / 地址的概念，别用云端那套校验把它拦下。
    // 模型没装好的情况由 TtsClient 给出「还没安装好」的提示。
    if (!provider.needsApiKey) return null;
    if (!provider.hasApiKey) {
      return '语音合成厂商「${provider.name}」还没填 API Key';
    }
    if (provider.baseUrl.trim().isEmpty) {
      return '语音合成厂商「${provider.name}」未配置 API 地址';
    }
    return null;
  }

  /// 音频落到临时目录。
  ///
  /// 顺手清掉上一次的朗读文件 —— 每次朗读都会生成一个新文件，
  /// 不清的话临时目录会被一条条念过的音频堆满。
  static Future<File> _writeTemp(int messageId, TtsAudio audio) async {
    final base = await getTemporaryDirectory();
    final dir = Directory(p.join(base.path, 'tts'));
    if (!await dir.exists()) await dir.create(recursive: true);

    await for (final entity in dir.list()) {
      if (entity is File && p.basename(entity.path).startsWith('tts_')) {
        try {
          await entity.delete();
        } catch (_) {
          // 正在被播放器占用就跳过，下次再说
        }
      }
    }

    final stamp = DateTime.now().millisecondsSinceEpoch;
    final file = File(p.join(dir.path, 'tts_${messageId}_$stamp${audio.extension}'));
    await file.writeAsBytes(audio.bytes, flush: true);
    return file;
  }

  /// `Exception: xxx` → `xxx`（不要把异常类名念给用户看）
  static String _readable(Object error) {
    var s = error.toString().trim();
    for (final prefix in const ['Exception: ', 'Exception：']) {
      if (s.startsWith(prefix)) s = s.substring(prefix.length).trim();
    }
    return s.isEmpty ? '朗读失败' : s;
  }
}
