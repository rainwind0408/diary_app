import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../data/models/diary_entry.dart';
import '../models/ai_provider.dart';
import '../models/media_marker.dart';
import 'ai_config_store.dart';
import 'local_model_store.dart';
import 'stt_client.dart';

/// 日记媒体的 I/O 编排：列清单、解析绝对路径、转写录音。
///
/// 纯逻辑（marker 编解码、路径守卫、清单项的 JSON 形态、格式化）
/// 全在 `models/media_marker.dart` 里，可以在纯 Dart VM 单测；
/// 这里只做「碰文件系统 / 碰插件」的部分。
class DiaryMediaService {
  DiaryMediaService._();

  /// 超过这个时长（毫秒）的录音，工具会先让模型问用户要不要转写。
  ///
  /// 5 分钟 —— 转写是**第二次付费请求**，不该在用户无意间被触发。
  static const int longAudioThresholdMs = 5 * 60 * 1000;

  static String? _cachedAppDir;

  /// 应用文档目录（图片/录音的根）。
  ///
  /// 与 `ImageService._imageDir` / `DiaryAudioService._audioDir` 同源，
  /// 都走 `getApplicationDocumentsDirectory()`。
  static Future<String> appDir() async {
    final cached = _cachedAppDir;
    if (cached != null) return cached;
    final dir = await getApplicationDocumentsDirectory();
    _cachedAppDir = dir.path;
    return _cachedAppDir!;
  }

  /// 列出这篇日记里**可用**的图片。
  ///
  /// `index` 按数据库里的位置（1 起）而不是「过滤后的位置」——
  /// 这样模型说的「第 2 张」在两处指向同一张图，不会因为某张路径损坏而错位。
  static Future<List<DiaryMediaItem>> imagesOf(DiaryEntry entry) async {
    final root = await appDir();
    final paths = entry.images.map((e) => e.path).toList();
    return _collect(
      appDir: root,
      storedPaths: paths,
      durationsMs: List<int?>.filled(paths.length, null),
      guard: DiaryMediaPath.isImage,
    );
  }

  /// 列出这篇日记里**可用**的录音
  static Future<List<DiaryMediaItem>> audiosOf(DiaryEntry entry) async {
    final root = await appDir();
    final paths = entry.audios.map((e) => e.path).toList();
    return _collect(
      appDir: root,
      storedPaths: paths,
      durationsMs: entry.audios.map((e) => e.durationMs).toList(),
      guard: DiaryMediaPath.isAudio,
    );
  }

  /// 取第 [index] 张图片（1 起）；不存在或路径非法时返回 null
  static Future<DiaryMediaItem?> imageAt(DiaryEntry entry, int index) async {
    for (final item in await imagesOf(entry)) {
      if (item.index == index) return item;
    }
    return null;
  }

  /// 取第 [index] 段录音（1 起）；不存在或路径非法时返回 null
  static Future<DiaryMediaItem?> audioAt(DiaryEntry entry, int index) async {
    for (final item in await audiosOf(entry)) {
      if (item.index == index) return item;
    }
    return null;
  }

  /// 转写一段录音，返回纯文本。
  ///
  /// **未配 STT 厂商 / 识别失败一律抛异常** —— 由工具转成 JSON 错误，
  /// 让模型如实告诉用户「读不了」。静默返回空串是最坏的结果：
  /// 模型会顺着空白编出一段根本不存在的录音内容。
  static Future<String> transcribe(String absPath) async {
    final config = await AiConfigStore.load();
    final provider = config.activeProvider(AiCapability.stt);
    if (provider == null) {
      throw Exception('还没有配置语音识别厂商，无法读取录音内容');
    }
    return SttClient.transcribe(
      provider: provider,
      model: config.activeModel(AiCapability.stt) ?? '',
      audioPath: absPath,
      // 选中的是本地模型时给出它的目录；否则为 null（云端链路不用）
      localModelDir: await LocalModelStore.dirForProvider(provider),
    );
  }

  // ─────────────────────────────────────────────
  // 内部
  // ─────────────────────────────────────────────

  static Future<List<DiaryMediaItem>> _collect({
    required String appDir,
    required List<String> storedPaths,
    required List<int?> durationsMs,
    required bool Function({required String appDir, required String storedPath})
        guard,
  }) async {
    final items = <DiaryMediaItem>[];
    for (var i = 0; i < storedPaths.length; i++) {
      final stored = storedPaths[i];
      if (!guard(appDir: appDir, storedPath: stored)) continue;
      final abs = DiaryMediaPath.resolve(appDir: appDir, storedPath: stored);
      if (abs == null) continue;
      items.add(DiaryMediaItem(
        index: i + 1,
        storedPath: stored,
        absPath: abs,
        name: p.posix.basename(abs),
        sizeBytes: await _sizeOf(abs),
        durationMs: i < durationsMs.length ? durationsMs[i] : null,
      ));
    }
    return items;
  }

  /// 读文件大小；读不到按 0 处理（不影响模型理解清单）
  static Future<int> _sizeOf(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) return await file.length();
    } catch (_) {
      // 忽略
    }
    return 0;
  }
}
