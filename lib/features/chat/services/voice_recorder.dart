import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// 语音采集封装（record 插件）。
///
/// 统一采集为 16kHz 单声道 WAV —— OpenAI 与 DashScope 都直接接受，
/// 省掉「格式不被识别」这类难查的问题。
///
/// 识别逻辑在纯 Dart 的 `stt_client.dart` 里，这里只负责采集与文件管理。
class VoiceRecorder {
  final AudioRecorder _recorder = AudioRecorder();
  String? _path;

  /// 返回是否成功开始采集（无权限时返回 false）
  Future<bool> start() async {
    if (!await _recorder.hasPermission()) return false;

    final dir = await getTemporaryDirectory();
    final path = p.join(
      dir.path,
      'stt_${DateTime.now().millisecondsSinceEpoch}.wav',
    );

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
        bitRate: 256000,
      ),
      path: path,
    );
    _path = path;
    return true;
  }

  /// 停止采集并返回文件路径
  Future<String?> stop() async {
    try {
      final result = await _recorder.stop();
      return result ?? _path;
    } catch (_) {
      return _path;
    }
  }

  /// 放弃本次采集并删除文件
  Future<void> cancel() async {
    try {
      await _recorder.cancel();
    } catch (_) {
      // 忽略：可能已经停了
    }
    final path = _path;
    if (path != null) {
      try {
        final f = File(path);
        if (await f.exists()) await f.delete();
      } catch (_) {
        // 删不掉也无所谓，临时目录会被系统清理
      }
    }
  }

  Future<void> dispose() async {
    try {
      await _recorder.dispose();
    } catch (_) {
      // 忽略
    }
  }
}
