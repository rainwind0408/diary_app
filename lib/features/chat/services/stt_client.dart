/// 语音识别（STT）客户端 —— **纯 Dart**，只依赖 dart:io / dart:convert / http，
/// 不引入 Flutter，便于独立测试。
///
/// 支持三种协议（见 [AiProtocol]）：
/// - `openAiCompat` / `custom` → `POST {base}/audio/transcriptions`（multipart，取 `text`）
/// - `dashScope` → `POST {base}/chat/completions` + `input_audio`（取 `choices[0].message.content`）
/// - `local` → **不走网络**，交给 `LocalAsrEngine` 跑本地 sherpa-onnx 模型
///
/// 讯飞 / 百度 / 腾讯需要各自的签名算法（HMAC、TC3 等），本期未实现，
/// 调用时给出明确提示而不是静默失败。
library;

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../models/ai_provider.dart';
import '../models/local_model.dart';
import 'local_speech_worker.dart';
import 'tts_codec.dart';

class SttClient {
  SttClient._();

  /// DashScope 对 base64 音频的硬限制
  static const int dashScopeMaxBase64Bytes = 10 * 1024 * 1024;

  /// 把一段语音转成文字。
  ///
  /// [localModelDir] 只在 `protocol == AiProtocol.local` 时用到 ——
  /// 本地引擎刻意不自己解析目录（那样它就得依赖 path_provider，
  /// 也就没法在纯 Dart CLI 里跑），所以由调用方（`LocalModelStore`）解析后传进来。
  static Future<String> transcribe({
    required AiProvider provider,
    required String model,
    required String audioPath,
    String? localModelDir,
  }) async {
    final file = File(audioPath);
    if (!await file.exists()) {
      throw Exception('没找到刚才的语音文件');
    }

    // ── 本地模型：没有 Key / 地址的概念，先分流，别被下面的通用校验拦下 ──
    if (provider.protocol == AiProtocol.local) {
      final dir = (localModelDir ?? '').trim();
      if (dir.isEmpty) {
        throw Exception(
          '本地模型「${provider.name}」还没安装好，'
          '请到「AI 助手设置 → 语音识别」里点安装',
        );
      }
      final modelId = model.trim().isNotEmpty
          ? model.trim()
          : (LocalModelCatalog.modelIdOfProvider(provider.id) ?? '');
      final text = await LocalSpeechWorker.transcribe(
        modelId: modelId,
        modelDir: dir,
        audioPath: audioPath,
      );
      if (text.trim().isEmpty) {
        // 与云端分支保持同一句提示 —— 用户不需要知道这句话是谁说的
        throw Exception('语音识别返回为空');
      }
      return text.trim();
    }

    if (!provider.hasApiKey) {
      throw Exception('请先在「AI 助手设置 → 语音识别」里配置 API Key');
    }
    if (provider.baseUrl.isEmpty) {
      throw Exception('该语音厂商未配置 API 地址');
    }
    // 有人会把厂商的 WebSocket 地址（wss://openspeech.bytedance.com/...）
    // 直接粘进来，提前拦掉并说清楚原因，别让用户去看 "Unsupported scheme"。
    final urlProblem = describeVoiceBaseUrlProblem(provider.baseUrl, '语音识别');
    if (urlProblem != null) throw Exception(urlProblem);

    switch (provider.protocol) {
      case AiProtocol.openAiCompat:
      case AiProtocol.custom:
        return _openAiCompat(provider, model, file);
      case AiProtocol.dashScope:
        return _dashScope(provider, model, file);
      case AiProtocol.local:
        // 上面已经分流过了；这里只是为了让 switch 保持穷尽
        throw StateError('本地模型应在上方分流，不该走到这里');
      case AiProtocol.system:
        // 系统语音只覆盖「朗读」。识别走不通 —— 真机实测：唯一对外的
        // RecognitionService 要签名级 BIND_VOICE_INTERACTION，第三方拿不到。
        // 详见 `不推送/技术方案/系统语音复用可行性分析-2026-10-08.md` §3。
        throw Exception(
          '「系统语音」只用于朗读，不能做语音识别。'
          '请到「AI 助手设置 → 语音识别」里改用云端厂商或本地模型',
        );
      case AiProtocol.xunfei:
      case AiProtocol.baidu:
      case AiProtocol.tencent:
        throw Exception(
          '${provider.protocol.label} 的语音识别签名协议尚未实现，'
          '请在设置里改用「OpenAI 兼容」或「阿里 DashScope」厂商',
        );
    }
  }

  // ─────────────────────────────────────────────
  // 协议一：OpenAI 标准 /audio/transcriptions
  // ─────────────────────────────────────────────

  static Future<String> _openAiCompat(
    AiProvider provider,
    String model,
    File file,
  ) async {
    final uri = Uri.parse('${trimTrailingSlash(provider.baseUrl)}/audio/transcriptions');
    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer ${provider.apiKey}'
      ..fields['model'] = model.isEmpty ? 'whisper-1' : model
      ..fields['response_format'] = 'json'
      ..files.add(await http.MultipartFile.fromPath('file', file.path));

    final streamed = await request.send().timeout(const Duration(seconds: 90));
    final body = await streamed.stream.bytesToString();

    if (streamed.statusCode != 200) {
      throw Exception('语音识别失败 (${streamed.statusCode})：${shortBody(body)}');
    }

    final decoded = jsonDecode(body);
    final text = decoded is Map ? decoded['text'] : null;
    if (text is! String || text.trim().isEmpty) {
      throw Exception('语音识别返回为空');
    }
    return text.trim();
  }

  // ─────────────────────────────────────────────
  // 协议二：DashScope 的 chat-completions 形态
  // ─────────────────────────────────────────────

  static Future<String> _dashScope(
    AiProvider provider,
    String model,
    File file,
  ) async {
    final bytes = await file.readAsBytes();
    final dataUri = 'data:${audioMimeOf(file.path)};base64,${base64Encode(bytes)}';

    if (dataUri.length > dashScopeMaxBase64Bytes) {
      throw Exception('说得太久，超过了识别服务的体积上限');
    }

    final body = <String, dynamic>{
      'model': model.isEmpty ? 'qwen3-asr-flash' : model,
      'messages': [
        {
          'role': 'user',
          'content': [
            {
              'type': 'input_audio',
              'input_audio': {'data': dataUri},
            },
          ],
        },
      ],
      'stream': false,
      'asr_options': {'enable_itn': false},
    };

    final response = await http
        .post(
          Uri.parse('${normalizeDashScopeBase(provider.baseUrl)}/chat/completions'),
          headers: {
            'Authorization': 'Bearer ${provider.apiKey}',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 120));

    if (response.statusCode != 200) {
      throw Exception(
        '语音识别失败 (${response.statusCode})：'
        '${shortBody(utf8.decode(response.bodyBytes))}',
      );
    }

    final text = extractDashScopeText(
      jsonDecode(utf8.decode(response.bodyBytes)),
    );
    if (text == null || text.trim().isEmpty) {
      throw Exception('语音识别返回为空');
    }
    return text.trim();
  }

  // ─────────────────────────────────────────────
  // 纯工具
  // ─────────────────────────────────────────────

  /// 从 `choices[0].message.content` 取识别文本（兼容 content 为数组的返回形态）
  static String? extractDashScopeText(dynamic decoded) {
    if (decoded is! Map) return null;
    final choices = decoded['choices'];
    if (choices is! List || choices.isEmpty) return null;
    final first = choices.first;
    if (first is! Map) return null;
    final message = first['message'];
    if (message is! Map) return null;

    final content = message['content'];
    if (content is String) return content;
    if (content is List) {
      final buf = StringBuffer();
      for (final part in content) {
        if (part is Map && part['text'] is String) {
          buf.write(part['text']);
        }
      }
      return buf.isEmpty ? null : buf.toString();
    }
    return null;
  }

  /// 把任意 DashScope 地址归一化到「兼容模式」根路径。
  ///
  /// 用户可能填原生 root（`https://dashscope.aliyuncs.com/api/v1`）也可能填
  /// 兼容模式 root；ASR 走的是后者，这里统一兜住。
  static String normalizeDashScopeBase(String baseUrl) {
    final trimmed = trimTrailingSlash(baseUrl);
    if (trimmed.contains('/compatible-mode/')) return trimmed;
    final uri = Uri.tryParse(trimmed);
    if (uri == null || uri.host.isEmpty) return trimmed;
    return '${uri.scheme}://${uri.host}/compatible-mode/v1';
  }

  /// 按扩展名推断音频 mime（识别不出时按 wav 处理，与采集格式一致）
  static String audioMimeOf(String path) {
    switch (p.extension(path).toLowerCase()) {
      case '.wav':
        return 'audio/wav';
      case '.mp3':
        return 'audio/mpeg';
      case '.m4a':
        return 'audio/mp4';
      case '.aac':
        return 'audio/aac';
      case '.ogg':
      case '.opus':
        return 'audio/ogg';
      case '.flac':
        return 'audio/flac';
      default:
        return 'audio/wav';
    }
  }

  static String trimTrailingSlash(String url) {
    var s = url.trim();
    while (s.endsWith('/')) {
      s = s.substring(0, s.length - 1);
    }
    return s;
  }

  /// 截断过长的错误响应体，避免把整个 HTML 错误页塞进提示里
  static String shortBody(String body) {
    final oneLine = body.replaceAll(RegExp(r'\s+'), ' ').trim();
    return oneLine.length <= 180 ? oneLine : '${oneLine.substring(0, 180)}…';
  }
}
