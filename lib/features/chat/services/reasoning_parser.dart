/// 从各家 API 返回的 `message` 里解析「思考过程」。
///
/// 只依赖 dart:core，不引入 Flutter / http，便于在纯 Dart VM 里独立测试
/// （`LlmService` 因为 import 了 package:http，没法被验证脚本直接引用）。
library;

class ReasoningParser {
  ReasoningParser._();

  /// 常见字段名，按出现频率排序：
  /// - `reasoning_content` —— DeepSeek-R1、Qwen3、Kimi
  /// - `reasoning`         —— OpenRouter、vLLM 等网关的写法
  static const List<String> keys = ['reasoning_content', 'reasoning'];

  /// 取思考过程；字段缺失、类型不对或只有空白时返回空串。
  ///
  /// 返回空串表示「这个模型没给思考过程」，界面据此决定不渲染面板 ——
  /// 所以绝不能抛异常，否则一次解析失败会毁掉整轮对话。
  static String fromMessage(Map<String, dynamic> message) {
    return rawFromMessage(message).trim();
  }

  /// 同 [fromMessage]，但**保留原始空白**。
  ///
  /// 流式场景必须用这个：分片里的空格是有效字符（`"先" + " " + "想"`），
  /// trim 会把帧间空格吃掉，导致最终文本粘连成「先想」。
  /// 只取「有实质内容」的那一帧；若所有候选都只有空白，返回第一个非空值。
  static String rawFromMessage(Map<String, dynamic> message) {
    var whitespaceOnly = '';
    for (final key in keys) {
      final value = message[key];
      if (value is! String || value.isEmpty) continue;
      if (value.trim().isNotEmpty) return value;
      if (whitespaceOnly.isEmpty) whitespaceOnly = value;
    }
    return whitespaceOnly;
  }
}
