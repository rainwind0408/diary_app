/// 本地离线语音合成引擎（sherpa-onnx + Kokoro 多语）。
///
/// 与 [LocalAsrEngine] 一样是**纯 Dart**：不 import Flutter、不碰 path_provider，
/// 模型目录由调用方传入。所以它能在本机用纯 Dart CLI 跑真实模型验证。
///
/// ## 输出为什么是「自己编码的 WAV 字节」而不是 sherpa 的 `writeWave`
///
/// `writeWave` 要一个文件路径，而写文件得先有目录 —— 那就得引 path_provider，
/// 把这一层弄脏。WAV(PCM16) 的头只有 44 字节、格式固定，自己编码反而更短、
/// 更可控（见 [encodeWav16]），还能顺手把 +1.0 的溢出爆音修掉。
///
/// 编出来的字节直接交给现有的 [TtsAudio] / `TtsPlayer` 链路 ——
/// **播放那条路一行都不用改**。
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import '../models/local_model.dart';

class LocalTtsEngine {
  LocalTtsEngine._();

  static bool _bindingsReady = false;
  static sherpa.OfflineTts? _tts;
  static String? _ttsDir;

  /// 线程数。
  ///
  /// 取 4 是按实测定的（本机 16 核桌面 CPU，Kokoro int8 合成同一句中文 3.22 秒音频）：
  /// `1 线程 25.1s / 2 线程 20.2s / 4 线程 12.8s / 8 线程 12.2s`
  /// —— 4 之后基本没收益了。
  ///
  /// 之所以敢开 4：推理跑在 `LocalSpeechWorker` 的后台 isolate 里，
  /// 抢核也不会冻 UI（换线程数不会影响正确性，只影响速度）。
  static const int _numThreads = 4;

  /// UI 允许的语速范围（与云端一致）
  static const double minSpeed = 0.5;
  static const double maxSpeed = 2.0;

  static Future<void> _ensureBindings() async {
    if (_bindingsReady) return;
    await sherpa.initBindingsAsync();
    _bindingsReady = true;
  }

  static void release() {
    _tts?.free();
    _tts = null;
    _ttsDir = null;
  }

  /// 把一段文字合成为 **WAV 字节**。
  ///
  /// [voice] 可以是音色名（`zf_xiaoxiao`）或 sid 数字（`47`）；
  /// 留空 / 认不出会落到中文女声 Xiaoxiao（见 [KokoroVoices.resolve]）。
  static Future<Uint8List> synthesize({
    required String modelId,
    required String modelDir,
    required String text,
    String voice = '',
    double speed = 1.0,
  }) async {
    if (modelId != LocalModelCatalog.kokoroTtsId) {
      throw Exception('不认识的本地合成模型：$modelId');
    }
    final body = text.trim();
    if (body.isEmpty) {
      throw Exception('这条消息没有可朗读的文字');
    }

    await _ensureBindings();
    final tts = _ttsFor(modelDir);

    final sid = KokoroVoices.resolve(voice);
    final audio = tts.generate(
      text: body,
      sid: sid,
      speed: speed.clamp(minSpeed, maxSpeed).toDouble(),
    );

    if (audio.samples.isEmpty || audio.sampleRate <= 0) {
      throw Exception('本地语音合成没有产出音频');
    }
    return encodeWav16(audio.samples, audio.sampleRate);
  }

  // ─────────────────────────────────────────────

  static sherpa.OfflineTts _ttsFor(String modelDir) {
    final cached = _tts;
    if (cached != null && _ttsDir == modelDir) return cached;

    cached?.free();
    _tts = null;

    final model = _requireFile(modelDir, 'model.int8.onnx');
    final voices = _requireFile(modelDir, 'voices.bin');
    final tokens = _requireFile(modelDir, 'tokens.txt');
    final dataDir = _requireDir(modelDir, 'espeak-ng-data');

    // 词典是**逗号分隔的多本**（官方示例：us-en + zh）
    final lexicons = <String>[
      p.join(modelDir, 'lexicon-us-en.txt'),
      p.join(modelDir, 'lexicon-zh.txt'),
    ].where((f) => File(f).existsSync()).join(',');
    if (lexicons.isEmpty) {
      throw Exception('本地模型缺少词典文件（lexicon-*.txt），建议删掉重新安装');
    }

    // 中文的数字 / 日期 / 电话号码正则化规则。缺哪个就少哪个，
    // 不让「少一个 fst」直接把朗读搞挂。
    final ruleFsts = <String>[
      'phone-zh.fst',
      'date-zh.fst',
      'number-zh.fst',
    ].map((n) => p.join(modelDir, n)).where((f) => File(f).existsSync()).join(',');

    final config = sherpa.OfflineTtsConfig(
      model: sherpa.OfflineTtsModelConfig(
        kokoro: sherpa.OfflineTtsKokoroModelConfig(
          model: model,
          voices: voices,
          tokens: tokens,
          // ★ 必需。`kokoro-multi-lang-lexicon.cc` 的构造函数会**无条件**
          //   调用 InitEspeak(data_dir)，遇到生僻词 / 英文夹杂还会回退到 espeak-ng。
          dataDir: dataDir,
          lexicon: lexicons,
          // lang 刻意留空：只要给了 lexicon，就不需要它（C++ 源码注释明确说明）。
        ),
        numThreads: _numThreads,
        debug: false,
        provider: 'cpu',
      ),
      ruleFsts: ruleFsts,
      maxNumSenetences: 1,
    );

    final tts = sherpa.OfflineTts(config);
    _tts = tts;
    _ttsDir = modelDir;
    return tts;
  }

  static String _requireFile(String dir, String name) {
    final path = p.join(dir, name);
    if (!File(path).existsSync()) {
      throw Exception('本地模型文件缺失：$name（可能没装好，建议删掉重新安装）');
    }
    return path;
  }

  static String _requireDir(String dir, String name) {
    final path = p.join(dir, name);
    if (!Directory(path).existsSync()) {
      throw Exception('本地模型缺少目录：$name/（可能没装好，建议删掉重新安装）');
    }
    return path;
  }
}

/// 把 sherpa 输出的 `Float32List`（[-1, 1] 单声道）编成 **16-bit PCM WAV**。
///
/// 抽成顶层函数是为了能在纯 Dart 环境里单测 —— 这段一旦写错，
/// 表现是「朗读没声音」或「噼里啪啦的杂音」，在手机上极难定位。
Uint8List encodeWav16(Float32List samples, int sampleRate) {
  const int channels = 1;
  const int bitsPerSample = 16;
  const int headerBytes = 44;
  const int bytesPerSample = bitsPerSample ~/ 8;

  final dataBytes = samples.length * bytesPerSample;
  final out = ByteData(headerBytes + dataBytes);

  void writeAscii(int offset, String s) {
    for (var i = 0; i < s.length; i++) {
      out.setUint8(offset + i, s.codeUnitAt(i));
    }
  }

  final byteRate = sampleRate * channels * bytesPerSample;

  writeAscii(0, 'RIFF');
  out.setUint32(4, 36 + dataBytes, Endian.little);
  writeAscii(8, 'WAVE');
  writeAscii(12, 'fmt ');
  out.setUint32(16, 16, Endian.little); // fmt 块长度
  out.setUint16(20, 1, Endian.little); // 1 = PCM
  out.setUint16(22, channels, Endian.little);
  out.setUint32(24, sampleRate, Endian.little);
  out.setUint32(28, byteRate, Endian.little);
  out.setUint16(32, channels * bytesPerSample, Endian.little); // 块对齐
  out.setUint16(34, bitsPerSample, Endian.little);
  writeAscii(36, 'data');
  out.setUint32(40, dataBytes, Endian.little);

  var offset = headerBytes;
  for (var i = 0; i < samples.length; i++) {
    var v = samples[i];
    // 模型偶尔会吐出 NaN / 超出 [-1,1] 的样本，直接转 int16 会绕回成爆音
    if (v.isNaN) {
      v = 0;
    } else if (v > 1.0) {
      v = 1.0;
    } else if (v < -1.0) {
      v = -1.0;
    }
    // 乘 32767 而不是 32768：+1.0 * 32768 会溢出成 -32768（听感是「啪」一声）
    out.setInt16(offset, (v * 32767).round(), Endian.little);
    offset += bytesPerSample;
  }

  return out.buffer.asUint8List();
}
