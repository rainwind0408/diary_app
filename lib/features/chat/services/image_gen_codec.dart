/// 生图请求 / 响应编解码。
///
/// 纯 Dart（只依赖 dart:convert / dart:typed_data），便于在纯 Dart VM 里单测。
library;

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

/// 从 `/images/generations` 响应里取出的图片载荷。
///
/// 两种形态都要接：
/// - `{"data":[{"url":"https://…"}]}` —— 还要再下载一次
/// - `{"data":[{"b64_json":"…"}]}`    —— 直接就是 base64
class ImagePayload {
  final String? url;
  final String? b64Json;

  /// 有些厂商会返回改写后的提示词（`revised_prompt`）
  final String revisedPrompt;

  const ImagePayload({this.url, this.b64Json, this.revisedPrompt = ''});

  bool get isEmpty =>
      (url == null || url!.isEmpty) && (b64Json == null || b64Json!.isEmpty);
}

/// 组装请求体。
///
/// **刻意不带 `response_format`** —— 各家支持度不一，带上容易被 400 拒掉。
/// 返回 url 还是 b64 交给厂商决定，两种我们都能接。
///
/// [imageBase64] 是图生图的**兜底写法**：有些厂商没实现 `/images/edits`，
/// 而是在 `/images/generations` 的 JSON 里多收一个 `image` 字段。
Map<String, dynamic> buildImageRequestBody({
  required String model,
  required String prompt,
  int n = 1,
  String? imageBase64,
}) {
  final body = <String, dynamic>{'prompt': prompt, 'n': n};
  if (model.isNotEmpty) body['model'] = model;
  if (imageBase64 != null && imageBase64.isNotEmpty) {
    body['image'] = imageBase64;
  }
  return body;
}

/// 一个已经拼好的 multipart/form-data 请求体。
class MultipartPayload {
  /// 带 boundary 的 Content-Type
  final String contentType;
  final List<int> body;

  const MultipartPayload({required this.contentType, required this.body});
}

/// 拼 `/images/edits` 的 multipart 请求体（图生图）。
///
/// 为什么自己拼而不用 `http.MultipartRequest`：那玩意儿要指定图片的
/// `contentType`，得从 `http_parser` 拿 `MediaType` —— 而 `http_parser` 只是
/// `http` 的传递依赖，直接 import 会被 `depend_on_referenced_packages` 挑刺，
/// 为它改 pubspec 又不值得。multipart 的格式本身就二十行。
///
/// 纯 Dart，可以离线测。
MultipartPayload buildImageEditMultipart({
  required String boundary,
  required String prompt,
  required String model,
  required String fileName,
  required String mimeType,
  required List<int> imageBytes,
  int n = 1,
}) {
  final builder = BytesBuilder(copy: false);

  void field(String name, String value) {
    builder.add(utf8.encode('--$boundary\r\n'));
    builder.add(utf8.encode('Content-Disposition: form-data; name="$name"\r\n\r\n'));
    builder.add(utf8.encode('$value\r\n'));
  }

  field('prompt', prompt);
  field('n', '$n');
  if (model.isNotEmpty) field('model', model);

  builder.add(utf8.encode('--$boundary\r\n'));
  builder.add(utf8.encode(
    'Content-Disposition: form-data; name="image"; filename="${_safeFileName(fileName)}"\r\n',
  ));
  builder.add(utf8.encode('Content-Type: $mimeType\r\n\r\n'));
  builder.add(imageBytes);
  builder.add(utf8.encode('\r\n'));
  builder.add(utf8.encode('--$boundary--\r\n'));

  return MultipartPayload(
    contentType: 'multipart/form-data; boundary=$boundary',
    body: builder.takeBytes(),
  );
}

/// 文件名里的引号 / 换行会直接把 multipart 头撕坏，换成下划线
String _safeFileName(String name) {
  final cleaned = name.replaceAll(RegExp(r'[\\/:*?"<>|\r\n]'), '_').trim();
  return cleaned.isEmpty ? 'reference.png' : cleaned;
}

/// 生成一个足够独特的 boundary。
///
/// 只靠时间戳不够：Windows 上 `DateTime.now()` 的实际分辨率约 1ms，
/// 同一毫秒内连发两次会撞出**同一个 boundary**。虽然单次请求里无害
/// （boundary 只要不出现在正文里即可），但加 8 位随机就彻底没这个疑虑了。
String newMultipartBoundary() {
  final stamp = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
  final salt = _random.nextInt(0x100000000).toRadixString(16).padLeft(8, '0');
  return '----diaryAppBoundary$stamp$salt';
}

final Random _random = Random();

/// 这家是不是「压根没实现 /images/edits」，或者这个模型在上面不可用？
///
/// ## 为什么要把 5xx 也算进来（2026-10-05 实测补充）
///
/// 国内大量厂商 / 中转站**只实现了 `/images/generations`**，图生图靠在这个
/// 端点的 JSON 里多收一个 `image` 字段（base64）。直接打 `/images/edits`
/// 时，它们不是规规矩矩回 404，而是回：
///
/// - `503 no available server`（中转站「这个端点没有可用上游通道」）
/// - `500 could not convert string to float: ''`（端点存在但没接图，参数解析炸了）
///
/// 实测（`apihub.agnes-ai.com`，模型 `agnes-image-2.5-flash`）：
/// - `POST /images/edits` (multipart) → **503**
/// - `POST /images/generations` + `image`(base64) → **200**，且返回的 URL 里
///   带 `/images/i2i/`，说明上游**真的做了图生图**
///
/// 所以 5xx 必须一并兜底 —— 否则「图生图」在这些厂商上永远是坏的，
/// 而用户看到的只是一句莫名其妙的 503。
///
/// **429 不在内**：那是限流，立刻换个端点重试只会加重问题。
/// **401/403 也不在内**：那是鉴权问题，换端点一样过不去。
bool looksLikeMissingEditEndpoint(int statusCode) =>
    const {400, 404, 405, 415, 500, 501, 502, 503}.contains(statusCode);

/// 解析响应；结构不对或没图时返回 null（**不抛异常**）。
ImagePayload? parseImageResponse(Map<String, dynamic> json) {
  final data = json['data'];
  if (data is! List || data.isEmpty) return null;

  final first = data.first;
  if (first is! Map) return null;

  final url = first['url'];
  final b64 = first['b64_json'];
  final revised = first['revised_prompt'];

  final payload = ImagePayload(
    url: (url is String && url.isNotEmpty) ? url : null,
    b64Json: (b64 is String && b64.isNotEmpty) ? b64 : null,
    revisedPrompt: revised is String ? revised : '',
  );
  return payload.isEmpty ? null : payload;
}

/// 从 URL 猜扩展名。
///
/// 下载回来的图没有文件名，只能靠 URL；猜不出时按 png 处理
/// （OpenAI 与 DashScope 的默认输出都是 png）。
String guessImageExtension({String? url}) {
  final u = (url ?? '').toLowerCase();
  for (final ext in const ['.png', '.webp', '.gif', '.jpeg', '.jpg']) {
    if (u.contains(ext)) return ext;
  }
  return '.png';
}

/// 按扩展名给出 mime
String imageMimeOf(String ext) {
  switch (ext.toLowerCase()) {
    case '.jpg':
    case '.jpeg':
      return 'image/jpeg';
    case '.webp':
      return 'image/webp';
    case '.gif':
      return 'image/gif';
    default:
      return 'image/png';
  }
}

/// 解析 base64 图片数据。
///
/// 兼容 `data:image/png;base64,xxx` 与裸 base64 两种写法；
/// 解不出来返回 null（坏数据不该让整条链路炸掉）。
List<int>? decodeImageBase64(String raw) {
  var s = raw.trim();
  if (s.startsWith('data:')) {
    final comma = s.indexOf(',');
    if (comma > 0) s = s.substring(comma + 1);
  }
  if (s.isEmpty) return null;
  try {
    return base64Decode(s);
  } catch (_) {
    return null;
  }
}
