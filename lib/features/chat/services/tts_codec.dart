/// TTS（语音合成）请求 / 响应编解码。
///
/// 纯 Dart（只依赖 dart:convert / dart:typed_data），便于在纯 Dart VM 里单测 ——
/// 这里出错的表现是「点了朗读没声音 / 存出来一个打不开的文件」，
/// 界面上完全看不出原因，所以值得把每个分支都测到。
///
/// 支持两种协议：
/// - `openAiCompat` / `custom` → `POST {base}/audio/speech`，**直接返回音频字节**
/// - `dashScope` → `POST {root}/services/aigc/multimodal-generation/generation`，
///   返回 **JSON**，音频在 `output.audio.url`（非流式）或 `output.audio.data`（base64）
library;

import 'dart:convert';
import 'dart:typed_data';

import '../models/ai_provider.dart';

/// OpenAI 兼容协议的默认音色
const String openAiDefaultVoice = 'alloy';

/// DashScope 原生协议的默认音色（与 qwen3-tts-flash 配套）
const String dashScopeDefaultVoice = 'Cherry';

/// DashScope 未指定模型时的兜底（该接口的 `model` 是必填项）
const String dashScopeDefaultModel = 'qwen3-tts-flash';

/// 系统自带语音（`AiProtocol.system`）的默认「音色」。
///
/// ⚠️ 对系统语音来说这个字段其实是**语言标签**（locale），不是音色名 ——
/// 各家系统引擎的音色命名完全不统一，第三方拿不到一致的「音色」概念。
/// 定义在这里（而不是 `SystemTts` 里）是为了让本文件保持纯 Dart：
/// `SystemTts` 依赖 `flutter_tts`，而本文件要能在纯 Dart VM 里单测。
const String systemDefaultLocale = 'zh-CN';

/// 硅基流动（SiliconFlow）的默认音色**短名**。
///
/// ⚠️ 它的 `voice` 是官方硬性要求的 **`模型名:音色名`** 形态
/// （`FunAudioLLM/CosyVoice2-0.5B:alex`）—— 直接送通用的 `alloy` 会被 400 拒掉。
/// 所以这里不能复用 [openAiDefaultVoice]，必须单独给一套。
const String siliconFlowDefaultVoiceName = 'alex';

/// 硅基流动没指定模型时的兜底（拼 `模型名:音色名` 要用到模型名）
const String siliconFlowDefaultModel = 'FunAudioLLM/CosyVoice2-0.5B';

/// 硅基流动预置的 8 个音色（4 男 4 女），短名即可，前缀会自动补
const List<String> siliconFlowVoiceNames = [
  'alex', // 沉稳男声
  'benjamin', // 低沉男声
  'charles', // 磁性男声
  'david', // 欢快男声
  'anna', // 沉稳女声
  'bella', // 激情女声
  'claire', // 温柔女声
  'diana', // 欢快女声
];

/// OpenAI `speed` 的合法区间
const double minSpeed = 0.25;
const double maxSpeed = 4.0;

/// 把语速夹进合法区间。
///
/// `NaN` 也要兜住 —— 配置被手改坏（写成 `"speed": "abc"`）时可能读出 NaN，
/// 而 `NaN.clamp()` 会抛 `UnsupportedError`，不该因为一个滑块值把朗读搞崩。
double clampSpeed(double v) {
  if (v.isNaN) return 1.0;
  return v.clamp(minSpeed, maxSpeed).toDouble();
}

/// 该协议的默认音色；没有通用默认值的返回空串
String defaultVoiceFor(
  AiProtocol protocol, {
  String baseUrl = '',
  String model = '',
}) {
  switch (protocol) {
    case AiProtocol.dashScope:
      return dashScopeDefaultVoice;
    case AiProtocol.openAiCompat:
    case AiProtocol.custom:
      // 硅基流动的音色带模型名前缀，和通用的 alloy 不通用
      if (isSiliconFlowBase(baseUrl)) {
        return normalizeSiliconFlowVoice('', model);
      }
      return openAiDefaultVoice;
    case AiProtocol.local:
      // 本地 Kokoro 的音色是 `voices.bin` 里的**序号**（sid），不是名字，
      // 拼不出「默认音色字符串」。返回空串 = 用第 0 个音色，
      // 实际换算在 `LocalTtsEngine` 里做。
      return '';
    case AiProtocol.system:
      // 系统语音的「音色」其实是**语言标签**（见 [systemDefaultLocale]）。
      return systemDefaultLocale;
    case AiProtocol.xunfei:
    case AiProtocol.baidu:
    case AiProtocol.tencent:
      // 这几家的音色是各家自己的编号，没有可通用的默认值
      return '';
  }
}

/// 地址看起来是不是硅基流动
bool isSiliconFlowBase(String baseUrl) =>
    baseUrl.toLowerCase().contains('siliconflow');

/// 把用户填的音色归一成硅基流动要求的 `模型名:音色名`。
///
/// - 留空 → `模型名:alex`
/// - 只写短名（`alex`）→ `模型名:alex`
/// - 已经带冒号 → 原样返回，不动。这一支同时覆盖了两种合法写法：
///   预置音色 `FunAudioLLM/CosyVoice2-0.5B:bella`，
///   以及自建音色 `speech:名字:id:签名`（**再拼一次前缀就废了**）。
String normalizeSiliconFlowVoice(String requested, String model) {
  final v = requested.trim();
  if (v.contains(':')) return v;
  final m = model.trim().isEmpty ? siliconFlowDefaultModel : model.trim();
  return '$m:${v.isEmpty ? siliconFlowDefaultVoiceName : v}';
}

/// 用户填了就用用户的，没填就用协议默认
String resolveVoice(
  AiProtocol protocol,
  String requested, {
  String baseUrl = '',
  String model = '',
}) {
  final v = requested.trim();
  if (v.isEmpty) {
    return defaultVoiceFor(protocol, baseUrl: baseUrl, model: model);
  }
  // 非空但可能是短名，硅基流动那边还得补模型名前缀
  if (protocol == AiProtocol.openAiCompat || protocol == AiProtocol.custom) {
    if (isSiliconFlowBase(baseUrl)) {
      return normalizeSiliconFlowVoice(v, model);
    }
  }
  return v;
}

// ─────────────────────────────────────────────
// 请求体
// ─────────────────────────────────────────────

/// OpenAI 兼容 `POST /audio/speech` 的请求体。
///
/// `speed` 等于 1.0 时**不带这个字段** —— 它本来就是各家默认值，
/// 而少数网关对未知字段是直接 400 的。
Map<String, dynamic> buildSpeechRequestBody({
  required String model,
  required String input,
  required String voice,
  double speed = 1.0,
  String responseFormat = 'mp3',
}) {
  final body = <String, dynamic>{
    'input': input,
    'voice': voice,
    'response_format': responseFormat,
  };
  if (model.isNotEmpty) body['model'] = model;
  final s = clampSpeed(speed);
  if (s != 1.0) body['speed'] = s;
  return body;
}

/// DashScope 原生「非实时语音合成」的请求体。
///
/// 注意 `voice` 放在 `input` 里（不是顶层），且 `model` 必填 ——
/// 这是它与 OpenAI 形态最容易搞混的地方。
Map<String, dynamic> buildDashScopeSpeechBody({
  required String model,
  required String text,
  required String voice,
  String languageType = 'Chinese',
}) {
  return <String, dynamic>{
    'model': model.trim().isEmpty ? dashScopeDefaultModel : model.trim(),
    'input': <String, dynamic>{
      'text': text,
      'voice': voice,
      'language_type': languageType,
    },
  };
}

/// DashScope 原生 API 根路径。
///
/// TTS 走的是**原生**端点（`/services/aigc/multimodal-generation/generation`），
/// 不是兼容模式端点。用户完全可能把厂商地址填成兼容模式
/// （`.../compatible-mode/v1`），那样拼出来的 URL 必然 404，所以这里统一换回原生根。
String normalizeDashScopeNativeBase(String baseUrl) {
  final trimmed = trimTrailingSlash(baseUrl.trim());
  if (trimmed.isEmpty) return trimmed;
  if (!trimmed.contains('/compatible-mode/')) return trimmed;

  final uri = Uri.tryParse(trimmed);
  if (uri == null || uri.host.isEmpty) return trimmed;
  return '${uri.scheme}://${uri.host}/api/v1';
}

/// 去掉末尾斜杠（用户手填地址时经常多带一个）
String trimTrailingSlash(String url) {
  var s = url;
  while (s.endsWith('/')) {
    s = s.substring(0, s.length - 1);
  }
  return s;
}

/// 语音接口的地址必须是 http(s)。返回一句可读的原因；没问题时返回 null。
///
/// 为什么值得单独拦一下：有些厂商（火山 openspeech、讯飞实时听写）
/// **只有 WebSocket 接口**，用户很容易把 `wss://...` 直接粘进「地址」里。
/// 不拦的话，报出来的是 `package:http` 的 `Unsupported scheme: wss` ——
/// 字面没错，但用户根本猜不到「要换成 HTTP 厂商」。
///
/// [what] 是能力名（「语音识别」/「语音合成」），拼进提示里。
String? describeVoiceBaseUrlProblem(String baseUrl, String what) {
  final trimmed = baseUrl.trim();
  final uri = Uri.tryParse(trimmed);
  final scheme = uri?.scheme.toLowerCase() ?? '';
  if (scheme == 'ws' || scheme == 'wss') {
    return '$what的地址是 WebSocket（$scheme://），本项目只支持 HTTP 接口。'
        '请改用「OpenAI 兼容」的语音服务（例如硅基流动 / 通义）。';
  }
  if (scheme != 'http' && scheme != 'https') {
    return '$what的地址不是合法的 http(s) 链接：$trimmed';
  }
  if (uri == null || uri.host.isEmpty) {
    return '$what的地址缺少域名：$trimmed';
  }
  return null;
}

// ─────────────────────────────────────────────
// 响应
// ─────────────────────────────────────────────

/// DashScope 响应里的音频载荷（url 与 base64 二选一）
class DashScopeAudio {
  final String? url;
  final String? data;

  const DashScopeAudio({this.url, this.data});

  bool get isEmpty =>
      (url == null || url!.isEmpty) && (data == null || data!.isEmpty);

  @override
  String toString() => 'DashScopeAudio(url: $url, data: ${data?.length} chars)';
}

/// 从 DashScope 响应里取音频。
///
/// 非流式返回 `output.audio.url`（`data` 为空串）；流式的**中间** chunk 反过来。
/// 两种都接：有 data 用 data，否则用 url。
DashScopeAudio? parseDashScopeAudio(dynamic decoded) {
  if (decoded is! Map) return null;
  final output = decoded['output'];
  if (output is! Map) return null;
  final audio = output['audio'];
  if (audio is! Map) return null;

  final url = audio['url'];
  final data = audio['data'];
  final result = DashScopeAudio(
    url: url is String && url.trim().isNotEmpty ? url.trim() : null,
    data: data is String && data.trim().isNotEmpty ? data.trim() : null,
  );
  return result.isEmpty ? null : result;
}

/// DashScope 失败时的可读原因（`code` + `message`）
String? parseDashScopeError(dynamic decoded) {
  if (decoded is! Map) return null;
  final message = decoded['message'];
  if (message is String && message.trim().isNotEmpty) return message.trim();
  final code = decoded['code'];
  if (code is String && code.trim().isNotEmpty) return code.trim();
  return null;
}

/// 响应体是不是 JSON（而不是音频字节）？
///
/// 这是**真实存在**的坑：不少网关在 HTTP 200 里塞一段 JSON 错误
/// （`{"error":{"message":"..."}}`）。直接当音频写盘会得到一个打不开的文件，
/// 播放时只报一句「无法播放」，根本查不出原因。
bool looksLikeJsonPayload(List<int> bytes) {
  for (final b in bytes) {
    // 跳过前导空白（含 BOM 之外的常见几种）
    if (b == 0x20 || b == 0x09 || b == 0x0A || b == 0x0D) continue;
    return b == 0x7B || b == 0x5B; // '{' 或 '['
  }
  return false;
}

/// 从**字节魔数**猜音频容器格式（最可靠的一路，优先用它）
String? audioExtensionFromBytes(List<int> b) {
  bool at(int offset, List<int> sig) {
    if (offset + sig.length > b.length) return false;
    for (var i = 0; i < sig.length; i++) {
      if (b[offset + i] != sig[i]) return false;
    }
    return true;
  }

  // RIFF....WAVE
  if (at(0, const [0x52, 0x49, 0x46, 0x46]) &&
      at(8, const [0x57, 0x41, 0x56, 0x45])) {
    return '.wav';
  }
  if (at(0, const [0x4F, 0x67, 0x67, 0x53])) return '.ogg'; // OggS
  if (at(0, const [0x66, 0x4C, 0x61, 0x43])) return '.flac'; // fLaC
  if (at(0, const [0x49, 0x44, 0x33])) return '.mp3'; // ID3v2 标签开头
  if (at(4, const [0x66, 0x74, 0x79, 0x70])) return '.m4a'; // ....ftyp

  // MPEG 帧同步：0xFF 后跟 111xxxxx
  if (b.length >= 2 && b[0] == 0xFF && (b[1] & 0xE0) == 0xE0) {
    // layer 位（bit2-1）为 00 = ADTS AAC，否则是 MPEG 音频层（MP3）
    return (b[1] & 0x06) == 0x00 ? '.aac' : '.mp3';
  }
  return null;
}

/// 从 Content-Type 猜音频格式
String? audioExtensionFromContentType(String? contentType) {
  if (contentType == null) return null;
  final ct = contentType.toLowerCase().split(';').first.trim();
  switch (ct) {
    case 'audio/mpeg':
    case 'audio/mp3':
    case 'audio/mpeg3':
    case 'audio/x-mpeg-3':
      return '.mp3';
    case 'audio/wav':
    case 'audio/x-wav':
    case 'audio/wave':
    case 'audio/vnd.wave':
      return '.wav';
    case 'audio/ogg':
    case 'audio/opus':
      return '.ogg';
    case 'audio/aac':
      return '.aac';
    case 'audio/mp4':
    case 'audio/m4a':
    case 'audio/x-m4a':
      return '.m4a';
    case 'audio/flac':
    case 'audio/x-flac':
      return '.flac';
    default:
      return null;
  }
}

/// 从 URL 的路径扩展名猜音频格式（DashScope 会给一个带 `.wav` 的 OSS 链接）
String? audioExtensionFromUrl(String? url) {
  if (url == null || url.isEmpty) return null;
  final path = Uri.tryParse(url)?.path ?? url;
  final dot = path.lastIndexOf('.');
  if (dot < 0 || dot == path.length - 1) return null;
  final ext = path.substring(dot).toLowerCase();
  const known = {'.mp3', '.wav', '.ogg', '.opus', '.aac', '.m4a', '.flac'};
  return known.contains(ext) ? ext : null;
}

/// 综合猜音频扩展名。**顺序有讲究**：字节魔数 > Content-Type > URL。
///
/// 网关经常把 Content-Type 写成 `application/octet-stream` 甚至写错，
/// 而字节是不会骗人的。
String guessAudioExtension({
  List<int>? bytes,
  String? contentType,
  String? url,
}) {
  if (bytes != null && bytes.isNotEmpty) {
    final byBytes = audioExtensionFromBytes(bytes);
    if (byBytes != null) return byBytes;
  }
  return audioExtensionFromContentType(contentType) ??
      audioExtensionFromUrl(url) ??
      '.mp3';
}

/// 扩展名 → MIME（写文件时用）
String audioMimeOfExtension(String ext) {
  switch (ext.toLowerCase()) {
    case '.wav':
      return 'audio/wav';
    case '.ogg':
    case '.opus':
      return 'audio/ogg';
    case '.aac':
      return 'audio/aac';
    case '.m4a':
      return 'audio/mp4';
    case '.flac':
      return 'audio/flac';
    case '.mp3':
    default:
      return 'audio/mpeg';
  }
}

/// 把错误响应体变成一句能看懂的话
String describeSpeechError(int statusCode, String body) {
  final short = shortenBody(body);
  if (statusCode == 401 || statusCode == 403) {
    return '语音合成鉴权失败（$statusCode），请检查 API Key：$short';
  }
  if (statusCode == 429) {
    return '语音合成被限流（429），稍后再试：$short';
  }
  if (statusCode == 404) {
    return '语音合成接口不存在（404），请检查厂商地址：$short';
  }
  return '语音合成失败（$statusCode）：$short';
}

/// 截断过长的响应体，避免把整个 HTML 错误页塞进提示里
String shortenBody(String body, {int limit = 180}) {
  final oneLine = body.replaceAll(RegExp(r'\s+'), ' ').trim();
  return oneLine.length <= limit ? oneLine : '${oneLine.substring(0, limit)}…';
}

/// base64 → 字节；解不出来返回 null（不抛）
Uint8List? decodeAudioBase64(String raw) {
  var s = raw.trim();
  if (s.startsWith('data:')) {
    final comma = s.indexOf(',');
    if (comma < 0) return null;
    s = s.substring(comma + 1);
  }
  if (s.isEmpty) return null;
  try {
    return base64Decode(s);
  } catch (_) {
    return null;
  }
}

/// 朗读前把正文「洗」成适合念出来的文本。
///
/// 直接念 Markdown 会很怪：`**加粗**` 会念出星号，代码块会念成乱码，
/// 链接会念出整串 URL。这里做最小限度的清理。
String speechTextOf(String markdown) {
  var s = markdown;

  // 代码块整体去掉（念代码没有意义，而且最吵）
  s = s.replaceAll(RegExp(r'```[\s\S]*?```'), ' ');
  s = s.replaceAll(RegExp(r'~~~[\s\S]*?~~~'), ' ');
  // 行内代码去掉反引号，内容保留
  s = s.replaceAllMapped(RegExp(r'`([^`]*)`'), (m) => m.group(1) ?? '');
  // 图片整体去掉；链接只留文字
  s = s.replaceAll(RegExp(r'!\[[^\]]*\]\([^)]*\)'), ' ');
  s = s.replaceAllMapped(
    RegExp(r'\[([^\]]*)\]\([^)]*\)'),
    (m) => m.group(1) ?? '',
  );
  // 标题、引用、列表符号
  s = s.replaceAll(RegExp(r'^\s{0,3}#{1,6}\s*', multiLine: true), '');
  s = s.replaceAll(RegExp(r'^\s{0,3}>\s?', multiLine: true), '');
  s = s.replaceAll(RegExp(r'^\s{0,3}[-*+]\s+', multiLine: true), '');
  s = s.replaceAll(RegExp(r'^\s{0,3}\d+\.\s+', multiLine: true), '');
  // 分隔线
  s = s.replaceAll(
    RegExp(r'^\s{0,3}(?:-{3,}|\*{3,}|_{3,})\s*$', multiLine: true),
    '',
  );
  // 强调符号
  s = s.replaceAll(RegExp(r'(\*\*|__|\*|_)'), '');

  // 连续空行压成一个停顿，行内换行变空格
  s = s.replaceAll(RegExp(r'\n{2,}'), '。');
  s = s.replaceAll('\n', ' ');
  s = s.replaceAll(RegExp(r'[ \t]{2,}'), ' ').trim();
  return s;
}

/// 太长会被接口拒（DashScope 上限 512 token / 600 字符），
/// 这里在**句边界**截断，别把一句话念一半。
String truncateForSpeech(String text, {int maxChars = 600}) {
  if (text.length <= maxChars) return text;
  final head = text.substring(0, maxChars);
  final cut = _lastSentenceEnd(head);
  return cut > maxChars ~/ 2 ? head.substring(0, cut) : head;
}

int _lastSentenceEnd(String s) {
  const marks = ['。', '！', '？', '；', '.', '!', '?', ';', '\n'];
  var best = -1;
  for (final m in marks) {
    final i = s.lastIndexOf(m);
    if (i > best) best = i;
  }
  return best < 0 ? -1 : best + 1;
}
