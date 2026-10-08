/// 一次生图的结果（图片已落盘到应用私有目录）。
///
/// 纯 Dart，便于单测。
library;

import 'dart:convert';

class ImageGenResult {
  /// 已落盘的本地绝对路径
  final String path;

  /// 用户（或模型）给出的描述
  final String prompt;

  /// 厂商改写后的提示词（有些会返回 `revised_prompt`）
  final String revisedPrompt;

  const ImageGenResult({
    required this.path,
    required this.prompt,
    this.revisedPrompt = '',
  });

  /// 标记类型。工具把它塞进返回值，界面据此认出「这条工具结果其实是一张图」。
  static const String markerKind = 'generated_image';

  /// 工具返回给模型的字符串（同时也是界面识别图片的依据）。
  ///
  /// 里面带上 prompt，模型才能接着往下聊「我刚画了什么」。
  String toMarker() => jsonEncode({
        'kind': markerKind,
        'path': path,
        'prompt': prompt,
        if (revisedPrompt.isNotEmpty) 'revised_prompt': revisedPrompt,
      });

  /// 从工具返回值里解析出结果；不是图片标记时返回 null。
  ///
  /// **绝不抛异常** —— 工具返回值可能是一段普通 JSON，也可能直接是报错文本。
  static ImageGenResult? tryParseMarker(String raw) {
    final trimmed = raw.trim();
    // 先做一个便宜的预筛，避免对每一段工具返回都跑 jsonDecode
    if (trimmed.isEmpty || !trimmed.startsWith('{')) return null;

    Object? decoded;
    try {
      decoded = jsonDecode(trimmed);
    } catch (_) {
      return null;
    }
    if (decoded is! Map) return null;
    if (decoded['kind'] != markerKind) return null;

    final path = decoded['path'];
    if (path is! String || path.isEmpty) return null;

    final prompt = decoded['prompt'];
    final revised = decoded['revised_prompt'];
    return ImageGenResult(
      path: path,
      prompt: prompt is String ? prompt : '',
      revisedPrompt: revised is String ? revised : '',
    );
  }
}
