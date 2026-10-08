/// 语音合成（TTS）客户端 —— **纯 Dart**，只依赖 dart:convert / dart:io / http，
/// 不引入 Flutter，便于独立测试。
///
/// 三种协议（见 [AiProtocol]）：
/// - `openAiCompat` / `custom` → `POST {base}/audio/speech`，**直接返回音频字节**
/// - `dashScope` → `POST {root}/services/aigc/multimodal-generation/generation`，
///   返回 JSON，音频在 `output.audio.url` 或 `output.audio.data`（base64）
/// - `local` → **不走网络**，交给 `LocalTtsEngine` 跑本地 sherpa-onnx 模型，
///   返回自己编码的 WAV 字节
///
/// 讯飞 / 百度 / 腾讯需要各自的签名算法（WebSocket + HMAC、TC3 等），本期未实现，
/// 调用时给出明确提示而不是静默失败 —— 与 [SttClient] 的处理保持一致。
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../models/ai_provider.dart';
import '../models/local_model.dart';
import 'local_speech_worker.dart';
import 'tts_codec.dart';

/// 合成好的音频
class TtsAudio {
  final Uint8List bytes;

  /// 含点，如 `.mp3`
  final String extension;

  final String mimeType;

  const TtsAudio({
    required this.bytes,
    required this.extension,
    required this.mimeType,
  });

  int get size => bytes.length;

  @override
  String toString() => 'TtsAudio($extension, ${bytes.length} bytes)';
}

class TtsClient {
  TtsClient._();

  static const Duration requestTimeout = Duration(seconds: 90);

  /// 把一段文字合成成音频。
  ///
  /// [localModelDir] 只在 `protocol == AiProtocol.local` 时用到（理由见 [SttClient.transcribe]）。
  static Future<TtsAudio> synthesize({
    required AiProvider provider,
    required String model,
    required String text,
    String voice = '',
    double speed = 1.0,
    String? localModelDir,
  }) async {
    final body = text.trim();
    if (body.isEmpty) {
      throw Exception('这条消息没有可朗读的文字');
    }

    // ── 本地模型：没有 Key / 地址 / 音色协议的概念，先分流 ──
    if (provider.protocol == AiProtocol.local) {
      final dir = (localModelDir ?? '').trim();
      if (dir.isEmpty) {
        throw Exception(
          '本地模型「${provider.name}」还没安装好，'
          '请到「AI 助手设置 → 语音合成」里点安装',
        );
      }
      final bytes = await LocalSpeechWorker.synthesize(
        // provider.id 是 `local-tts-kokoro-multilang`，而引擎认的是模型 id
        // `tts-kokoro-multilang` —— 直接拿 provider.id 会抛「不认识的本地合成模型」。
        modelId: model.trim().isNotEmpty
            ? model.trim()
            : (LocalModelCatalog.modelIdOfProvider(provider.id) ?? ''),
        modelDir: dir,
        text: body,
        // 音色对本地 Kokoro 来说是 sid（序号）或音色名，不做厂商归一化
        voice: voice,
        speed: speed,
      );
      return TtsAudio(
        bytes: bytes,
        extension: '.wav',
        mimeType: 'audio/wav',
      );
    }

    if (!provider.hasApiKey) {
      throw Exception('请先在「AI 助手设置 → 语音合成」里配置 API Key');
    }
    if (provider.baseUrl.trim().isEmpty) {
      throw Exception('该语音合成厂商未配置 API 地址');
    }
    // 与 SttClient 同一道防线：WebSocket 地址提前拦掉（见 tts_codec.dart）。
    final urlProblem = describeVoiceBaseUrlProblem(provider.baseUrl, '语音合成');
    if (urlProblem != null) throw Exception(urlProblem);

    // 音色解析要带上地址与模型：硅基流动的 `voice` 必须是 `模型名:音色名`，
    // 光知道协议是推不出来的（见 tts_codec.dart 的 normalizeSiliconFlowVoice）。
    final resolvedVoice = resolveVoice(
      provider.protocol,
      voice,
      baseUrl: provider.baseUrl,
      model: model,
    );

    switch (provider.protocol) {
      case AiProtocol.openAiCompat:
      case AiProtocol.custom:
        return _openAiCompat(
          provider: provider,
          model: model,
          text: body,
          voice: resolvedVoice,
          speed: speed,
        );
      case AiProtocol.dashScope:
        return _dashScope(
          provider: provider,
          model: model,
          text: body,
          voice: resolvedVoice,
        );
      case AiProtocol.local:
        // 上面已经分流过了；这里只是为了让 switch 保持穷尽
        throw StateError('本地模型应在上方分流，不该走到这里');
      case AiProtocol.system:
        // 系统语音是**边合成边播**，拿不到音频字节，所以它不可能走这条
        // 「返回字节」的路 —— 由 `TtsPlayer` 在调用本方法之前分流到 `SystemTts`。
        throw StateError('系统语音应在上方分流到 SystemTts，不该走到这里');
      case AiProtocol.xunfei:
      case AiProtocol.baidu:
      case AiProtocol.tencent:
        throw Exception(
          '${provider.protocol.label} 的语音合成签名协议尚未实现，'
          '请在设置里改用「OpenAI 兼容」或「阿里 DashScope」厂商',
        );
    }
  }

  // ─────────────────────────────────────────────
  // 协议一：OpenAI 标准 /audio/speech（裸音频字节）
  // ─────────────────────────────────────────────

  static Future<TtsAudio> _openAiCompat({
    required AiProvider provider,
    required String model,
    required String text,
    required String voice,
    required double speed,
  }) async {
    final uri = Uri.parse(
      '${trimTrailingSlash(provider.baseUrl)}/audio/speech',
    );

    final http.Response response;
    try {
      response = await http
          .post(
            uri,
            headers: {
              'Authorization': 'Bearer ${provider.apiKey}',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(
              buildSpeechRequestBody(
                model: model,
                input: text,
                voice: voice,
                speed: speed,
              ),
            ),
          )
          .timeout(requestTimeout);
    } catch (e) {
      throw Exception('语音合成请求失败：$e');
    }

    if (response.statusCode != 200) {
      throw Exception(
        describeSpeechError(
          response.statusCode,
          utf8.decode(response.bodyBytes, allowMalformed: true),
        ),
      );
    }

    return _fromBytes(
      response.bodyBytes,
      contentType: response.headers['content-type'],
    );
  }

  // ─────────────────────────────────────────────
  // 协议二：DashScope 原生（JSON + url / base64）
  // ─────────────────────────────────────────────

  static Future<TtsAudio> _dashScope({
    required AiProvider provider,
    required String model,
    required String text,
    required String voice,
  }) async {
    final root = normalizeDashScopeNativeBase(provider.baseUrl);
    final uri = Uri.parse(
      '$root/services/aigc/multimodal-generation/generation',
    );

    final http.Response response;
    try {
      response = await http
          .post(
            uri,
            headers: {
              'Authorization': 'Bearer ${provider.apiKey}',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(
              buildDashScopeSpeechBody(
                model: model,
                text: text,
                voice: voice,
              ),
            ),
          )
          .timeout(requestTimeout);
    } catch (e) {
      throw Exception('语音合成请求失败：$e');
    }

    final rawBody = utf8.decode(response.bodyBytes, allowMalformed: true);

    if (response.statusCode != 200) {
      throw Exception(describeSpeechError(response.statusCode, rawBody));
    }

    Object? decoded;
    try {
      decoded = jsonDecode(rawBody);
    } catch (_) {
      throw Exception('语音合成返回了无法解析的内容：${shortenBody(rawBody)}');
    }

    final audio = parseDashScopeAudio(decoded);
    if (audio == null) {
      final reason = parseDashScopeError(decoded);
      throw Exception(
        reason == null ? '语音合成没有返回音频数据' : '语音合成失败：$reason',
      );
    }

    // 优先用 base64（少一次网络往返），否则下载 url
    if (audio.data != null) {
      final bytes = decodeAudioBase64(audio.data!);
      if (bytes == null || bytes.isEmpty) {
        throw Exception('语音合成返回的音频数据无法解码');
      }
      return _fromBytes(bytes, url: audio.url);
    }

    return _download(audio.url!);
  }

  /// DashScope 返回的是 24 小时有效的 OSS 链接，得再拉一次
  static Future<TtsAudio> _download(String url) async {
    final http.Response response;
    try {
      response = await http.get(Uri.parse(url)).timeout(requestTimeout);
    } catch (e) {
      throw Exception('音频下载失败：$e');
    }
    if (response.statusCode != 200) {
      throw Exception('音频下载失败（${response.statusCode}）');
    }
    return _fromBytes(
      response.bodyBytes,
      contentType: response.headers['content-type'],
      url: url,
    );
  }

  // ─────────────────────────────────────────────
  // 收尾：把字节变成 [TtsAudio]，顺手挡掉「200 + JSON 错误」这个坑
  // ─────────────────────────────────────────────

  static TtsAudio _fromBytes(
    List<int> bytes, {
    String? contentType,
    String? url,
  }) {
    if (bytes.isEmpty) {
      throw Exception('语音合成返回了空音频');
    }

    // 真实坑：不少网关在 200 里塞一段 JSON 错误。直接当音频写盘会得到一个
    // 打不开的文件，播放时只报「无法播放」，查不出原因。
    if (looksLikeJsonPayload(bytes)) {
      final text = utf8.decode(bytes, allowMalformed: true);
      String detail = shortenBody(text);
      try {
        final decoded = jsonDecode(text);
        final parsed = parseDashScopeError(decoded);
        if (parsed != null) detail = parsed;
      } catch (_) {
        // 不是合法 JSON 就用原文
      }
      throw Exception('语音合成接口返回的是错误信息而不是音频：$detail');
    }

    final ext = guessAudioExtension(
      bytes: bytes,
      contentType: contentType,
      url: url,
    );
    return TtsAudio(
      bytes: bytes is Uint8List ? bytes : Uint8List.fromList(bytes),
      extension: ext,
      mimeType: audioMimeOfExtension(ext),
    );
  }
}
