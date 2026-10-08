/// 本地离线语音识别引擎（sherpa-onnx）。
///
/// ## 为什么是「纯 Dart」而且模型目录靠参数传入
///
/// 它**不 import Flutter、也不碰 path_provider** —— 模型目录由调用方解析后传进来。
/// 换来两个好处：
/// 1. 与本项目「协议层可离线测」的既有风格一致；
/// 2. 能在本机用**纯 Dart CLI + Windows 原生库**跑通真实模型
///    （Android 构建在本机被环境阻塞时的替代验收手段，见技术方案 §6.2）。
///
/// ## 两个模型的识别方式不一样，但对上层完全同构
///
/// | 模型 | 内核 | 用法 |
/// |---|---|---|
/// | SenseVoice Small | `OfflineRecognizer` | 本来就是非流式 |
/// | Zipformer 14M | `OnlineRecognizer` | 流式内核，**一次性喂完**再取最终结果 |
///
/// 用户已拍板「可以做非流式」，所以两者对外都只是
/// `Future<String> transcribe(音频路径)`，不做边说边出字。
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import '../models/local_model.dart';

class LocalAsrEngine {
  LocalAsrEngine._();

  static bool _bindingsReady = false;

  /// SenseVoice（非流式）
  static sherpa.OfflineRecognizer? _offline;
  static String? _offlineDir;

  /// Zipformer（流式内核）
  static sherpa.OnlineRecognizer? _online;
  static String? _onlineDir;

  /// 线程数。2 是手机上的稳妥值：再多对短音频收益很小，还会和 UI 抢核。
  static const int _numThreads = 2;

  /// 流式解码循环的安全上限 —— 正常情况下几十次就结束，
  /// 万一 `isReady` 因为模型异常一直为真，也不至于把界面卡死。
  static const int _maxDecodeSteps = 100000;

  /// 加载原生库。必须在创建任何 sherpa 对象之前调用，且**每个 isolate 各调一次**。
  static Future<void> _ensureBindings() async {
    if (_bindingsReady) return;
    await sherpa.initBindingsAsync();
    _bindingsReady = true;
  }

  /// 释放已加载的模型（切厂商、内存吃紧时用）
  static void release() {
    _offline?.free();
    _offline = null;
    _offlineDir = null;
    _online?.free();
    _online = null;
    _onlineDir = null;
  }

  /// 把一段录音转成文字。识别不出内容时返回**空串**（由调用方决定怎么提示）。
  static Future<String> transcribe({
    required String modelId,
    required String modelDir,
    required String audioPath,
  }) async {
    await _ensureBindings();

    final wave = sherpa.readWave(audioPath);
    if (wave.samples.isEmpty || wave.sampleRate <= 0) {
      throw Exception('读不出这段录音（本地识别需要 16kHz 单声道 WAV）');
    }

    switch (modelId) {
      case LocalModelCatalog.senseVoiceAsrId:
        return _transcribeSenseVoice(
          modelDir: modelDir,
          samples: wave.samples,
          sampleRate: wave.sampleRate,
        );
      case LocalModelCatalog.zipformerAsrId:
        return _transcribeZipformer(
          modelDir: modelDir,
          samples: wave.samples,
          sampleRate: wave.sampleRate,
        );
      default:
        throw Exception('不认识的本地识别模型：$modelId');
    }
  }

  // ─────────────────────────────────────────────
  // SenseVoice：OfflineRecognizer（真非流式）
  // ─────────────────────────────────────────────

  static String _transcribeSenseVoice({
    required String modelDir,
    required Float32List samples,
    required int sampleRate,
  }) {
    final recognizer = _offlineFor(modelDir);
    final stream = recognizer.createStream();
    try {
      stream.acceptWaveform(samples: samples, sampleRate: sampleRate);
      recognizer.decode(stream);
      return recognizer.getResult(stream).text.trim();
    } finally {
      stream.free();
    }
  }

  static sherpa.OfflineRecognizer _offlineFor(String modelDir) {
    final cached = _offline;
    if (cached != null && _offlineDir == modelDir) return cached;

    // 换模型：先释放旧的，别让两份模型同时占内存
    cached?.free();
    _offline = null;

    final model = _requireFile(modelDir, 'model.int8.onnx');
    final tokens = _requireFile(modelDir, 'tokens.txt');

    final config = sherpa.OfflineRecognizerConfig(
      model: sherpa.OfflineModelConfig(
        senseVoice: sherpa.OfflineSenseVoiceModelConfig(
          model: model,
          // 留空 = 让模型自己判别语种（五语：中英日韩粤）
          language: '',
          // 把「二零二六年」这类归一成数字，念日记时更符合直觉
          useInverseTextNormalization: true,
        ),
        tokens: tokens,
        numThreads: _numThreads,
        debug: false,
        provider: 'cpu',
      ),
    );

    final r = sherpa.OfflineRecognizer(config);
    _offline = r;
    _offlineDir = modelDir;
    return r;
  }

  // ─────────────────────────────────────────────
  // Zipformer 14M：OnlineRecognizer（流式内核，一次性喂完）
  // ─────────────────────────────────────────────

  static String _transcribeZipformer({
    required String modelDir,
    required Float32List samples,
    required int sampleRate,
  }) {
    final recognizer = _onlineFor(modelDir);
    final stream = recognizer.createStream();
    try {
      stream.acceptWaveform(samples: samples, sampleRate: sampleRate);
      // 告诉识别器「后面没有了」，它才会把尾音一并吐出来
      stream.inputFinished();

      var steps = 0;
      while (recognizer.isReady(stream) && steps < _maxDecodeSteps) {
        recognizer.decode(stream);
        steps++;
      }
      return recognizer.getResult(stream).text.trim();
    } finally {
      stream.free();
    }
  }

  static sherpa.OnlineRecognizer _onlineFor(String modelDir) {
    final cached = _online;
    if (cached != null && _onlineDir == modelDir) return cached;

    cached?.free();
    _online = null;

    final encoder = _requireFile(modelDir, 'encoder-epoch-99-avg-1.int8.onnx');
    final decoder = _requireFile(modelDir, 'decoder-epoch-99-avg-1.int8.onnx');
    final joiner = _requireFile(modelDir, 'joiner-epoch-99-avg-1.int8.onnx');
    final tokens = _requireFile(modelDir, 'tokens.txt');

    final config = sherpa.OnlineRecognizerConfig(
      model: sherpa.OnlineModelConfig(
        transducer: sherpa.OnlineTransducerModelConfig(
          encoder: encoder,
          decoder: decoder,
          joiner: joiner,
        ),
        tokens: tokens,
        numThreads: _numThreads,
        debug: false,
        provider: 'cpu',
      ),
      // ★ 关掉端点检测。默认开启是为了「边说边断句」，
      //   而我们是一次性喂完整段音频 —— 开着它会在句中的静音处
      //   把一句话切成多段，最终结果只剩最后一段。
      enableEndpoint: false,
    );

    final r = sherpa.OnlineRecognizer(config);
    _online = r;
    _onlineDir = modelDir;
    return r;
  }

  // ─────────────────────────────────────────────

  /// 模型文件必须在，否则 sherpa 的原生层只会打一行日志然后返回空结果 ——
  /// 那种「不报错但什么都识别不出来」最难查，所以在这里提前拦掉。
  static String _requireFile(String dir, String name) {
    final path = p.join(dir, name);
    if (!File(path).existsSync()) {
      throw Exception('本地模型文件缺失：$name（可能没装好，建议删掉重新安装）');
    }
    return path;
  }
}
