/// 本地语音的**后台线程宿主**。
///
/// ## 为什么非要有这一层
///
/// sherpa 的推理 API 是**同步 FFI**（`OfflineTts.generate()`、`Recognizer.decode()`
/// 都不是 Future）。同步 FFI 调用会**阻塞调用它的 isolate**。
///
/// 实测（`不推送/验证脚本/2026-10-08/sherpa_cli/tmp_probe_blocking.dart`）：
/// 在合成一段 3.2 秒中文的过程中挂一个 100ms 周期 Timer，**一次都没跳** ——
/// 整个 isolate 被冻结了 **16.6 秒**。
///
/// 如果直接在 Flutter 主 isolate 上调用，后果是：
/// 1. UI 完全冻死十几秒（手机上更久，Android 会弹 ANR / 直接杀进程）；
/// 2. `TtsPlayer` 那个 `synthesizing` 转圈**根本来不及重绘**，用户看到的是「点了没反应」。
///
/// 所以推理必须丢到后台 isolate。而**不能每次 `Isolate.run` 一个新 isolate** ——
/// 那样每次都要重新加载模型（SenseVoice 实测冷启动比热调用多约 4 秒）。
/// 这里用**常驻单例 isolate**：模型在它内部缓存，反复调用是热的。
///
/// ## 分工
///
/// - 本文件：跑在**主 isolate**，负责排队、转发、把结果搬回来；
/// - [LocalAsrEngine] / [LocalTtsEngine]：跑在**后台 isolate** 里，仍然是纯同步实现。
///
/// 这样两个引擎本身保持「纯 Dart、无 Flutter、可离线 CLI 验证」的性质不变
/// （本项目的 CLI 验证脚本正是直接调它们）。
library;

import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'local_asr_engine.dart';
import 'local_tts_engine.dart';

/// 后台线程报回来的失败。
///
/// `toString()` 刻意只返回消息本身（不带 `Exception: ` 前缀）——
/// 调用方与界面都直接把它当提示文案用，多加一层前缀反而要在好几处剥。
class LocalSpeechException implements Exception {
  final String message;

  const LocalSpeechException(this.message);

  @override
  String toString() => message;
}

class LocalSpeechWorker {
  LocalSpeechWorker._();

  static Isolate? _isolate;
  static SendPort? _tx;
  static ReceivePort? _rx;
  static StreamSubscription<dynamic>? _rxSub;
  static Completer<void>? _starting;

  /// 已发出、还没回来的请求
  static final Map<int, Completer<Object?>> _pending = {};
  static int _seq = 0;

  /// 后台线程是否已就绪
  static bool get isRunning => _tx != null;

  // ─────────────────────────────────────────────
  // 对外 API
  // ─────────────────────────────────────────────

  /// 转写一段录音。语义与 [LocalAsrEngine.transcribe] 完全一致。
  static Future<String> transcribe({
    required String modelId,
    required String modelDir,
    required String audioPath,
  }) async {
    final v = await _send({
      'op': 'asr',
      'modelId': modelId,
      'modelDir': modelDir,
      'audioPath': audioPath,
    });
    if (v is String) return v;
    throw const LocalSpeechException('本地识别没有返回文字');
  }

  /// 合成一段语音，返回 **WAV 字节**。语义与 [LocalTtsEngine.synthesize] 完全一致。
  static Future<Uint8List> synthesize({
    required String modelId,
    required String modelDir,
    required String text,
    String voice = '',
    double speed = 1.0,
  }) async {
    final v = await _send({
      'op': 'tts',
      'modelId': modelId,
      'modelDir': modelDir,
      'text': text,
      'voice': voice,
      'speed': speed,
    });
    if (v is Uint8List) return v;
    throw const LocalSpeechException('本地合成没有返回音频');
  }

  /// 释放后台线程里缓存的模型（换厂商 / 内存吃紧时用）。
  /// 线程本身留着 —— 下次调用直接复用。
  static Future<void> release() async {
    if (_tx == null) return;
    try {
      await _send({'op': 'release'});
    } catch (_) {
      // 释放失败无所谓，别让它冒到界面上
    }
  }

  /// 彻底关掉后台线程（测试用；App 里不需要主动调）
  static Future<void> shutdown() async {
    final iso = _isolate;
    _reset(failPendingWith: '本地语音后台线程已关闭');
    await _rxSub?.cancel();
    _rxSub = null;
    _rx?.close();
    _rx = null;
    iso?.kill(priority: Isolate.immediate);
    _isolate = null;
  }

  // ─────────────────────────────────────────────
  // 启动与通信
  // ─────────────────────────────────────────────

  static Future<void> _ensure() async {
    if (_tx != null) return;
    final starting = _starting;
    if (starting != null) return starting.future;

    final c = Completer<void>();
    _starting = c;
    try {
      final rx = ReceivePort();
      _rx = rx;
      final ready = Completer<SendPort>();

      _rxSub = rx.listen((msg) {
        // 第一条消息是后台线程的 SendPort
        if (msg is SendPort) {
          if (!ready.isCompleted) ready.complete(msg);
          return;
        }
        // isolate 抛了未捕获异常 → [error, stackTrace]
        if (msg is List && msg.length == 2) {
          _reset(failPendingWith: '本地语音后台线程出错：${msg[0]}');
          return;
        }
        // isolate 退出 → null
        if (msg == null) {
          _reset(failPendingWith: '本地语音后台线程已退出');
          return;
        }
        if (msg is Map) {
          final id = msg['id'];
          if (id is! int) return;
          final completer = _pending.remove(id);
          if (completer == null) return;
          if (msg['ok'] == true) {
            completer.complete(msg['value']);
          } else {
            completer.completeError(
              LocalSpeechException('${msg['error'] ?? '未知错误'}'),
            );
          }
        }
      });

      _isolate = await Isolate.spawn(
        _workerEntry,
        rx.sendPort,
        debugName: 'local-speech',
        errorsAreFatal: false,
        onError: rx.sendPort,
        onExit: rx.sendPort,
      );
      _tx = await ready.future;
      c.complete();
    } catch (e) {
      _reset(failPendingWith: '本地语音后台线程启动失败：$e');
      c.completeError(e);
      rethrow;
    } finally {
      _starting = null;
    }
  }

  static Future<Object?> _send(Map<String, Object?> req) async {
    await _ensure();
    final tx = _tx;
    if (tx == null) {
      throw const LocalSpeechException('本地语音后台线程没能启动');
    }
    final id = ++_seq;
    final c = Completer<Object?>();
    _pending[id] = c;
    tx.send({...req, 'id': id});
    return c.future;
  }

  /// 把状态清干净，并让所有在飞的请求失败。
  ///
  /// 必须让它们**失败**而不是永远挂着 —— 挂着的 Future 在界面上就是
  /// 「一直转圈、永远不结束」，比报错难查得多。
  static void _reset({required String failPendingWith}) {
    _tx = null;
    final pending = List.of(_pending.values);
    _pending.clear();
    for (final c in pending) {
      if (!c.isCompleted) {
        c.completeError(LocalSpeechException(failPendingWith));
      }
    }
  }
}

// ─────────────────────────────────────────────
// 后台 isolate 侧
// ─────────────────────────────────────────────

/// 后台线程主循环。**必须是顶层函数**（`Isolate.spawn` 的要求）。
Future<void> _workerEntry(SendPort toMain) async {
  final rx = ReceivePort();
  toMain.send(rx.sendPort);

  await for (final raw in rx) {
    if (raw is! Map) continue;
    final id = raw['id'];
    try {
      switch (raw['op']) {
        case 'asr':
          final text = await LocalAsrEngine.transcribe(
            modelId: raw['modelId'] as String,
            modelDir: raw['modelDir'] as String,
            audioPath: raw['audioPath'] as String,
          );
          toMain.send({'id': id, 'ok': true, 'value': text});

        case 'tts':
          final bytes = await LocalTtsEngine.synthesize(
            modelId: raw['modelId'] as String,
            modelDir: raw['modelDir'] as String,
            text: raw['text'] as String,
            voice: (raw['voice'] as String?) ?? '',
            speed: (raw['speed'] as num?)?.toDouble() ?? 1.0,
          );
          toMain.send({'id': id, 'ok': true, 'value': bytes});

        case 'release':
          LocalAsrEngine.release();
          LocalTtsEngine.release();
          toMain.send({'id': id, 'ok': true, 'value': null});

        default:
          toMain.send({
            'id': id,
            'ok': false,
            'error': '未知的本地语音操作：${raw['op']}',
          });
      }
    } catch (e) {
      toMain.send({'id': id, 'ok': false, 'error': _plainMessage(e)});
    }
  }
}

/// 把异常转成给人看的一句话（剥掉 `Exception: ` 前缀）
String _plainMessage(Object? e) {
  var s = (e ?? '未知错误').toString().trim();
  for (final prefix in const ['Exception: ', 'Exception：']) {
    if (s.startsWith(prefix)) {
      s = s.substring(prefix.length).trim();
      break;
    }
  }
  return s.isEmpty ? '未知错误' : s;
}
