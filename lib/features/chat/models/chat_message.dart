import 'dart:convert';

import 'chat_attachment.dart';

class ChatMessage {
  final String role; // 'user', 'assistant', 'system', 'tool'
  final String content;

  /// 模型的思考过程。**只用于界面展示**：DeepSeek 等厂商明确要求
  /// 不要把 `reasoning_content` 回传，否则报 400，所以 [toApiMap] 里不带它。
  final String reasoning;
  final List<ToolCall>? toolCalls;
  final String? toolCallId;
  final String? toolName;
  final List<ChatAttachment> attachments;
  final DateTime timestamp;

  /// 流式响应的结束原因（`stop` / `length` / `tool_calls` …）。
  ///
  /// **不落库、不回传 API** —— 只用来判断这次回答是不是被 token 上限截断了
  /// （`length`），好给用户一句明确的提示。
  final String finishReason;

  ChatMessage({
    required this.role,
    required this.content,
    this.reasoning = '',
    this.toolCalls,
    this.toolCallId,
    this.toolName,
    this.attachments = const [],
    this.finishReason = '',
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  bool get hasAttachments => attachments.isNotEmpty;

  bool get hasReasoning => reasoning.trim().isNotEmpty;

  /// 是否因为撞到 token 上限而被截断
  bool get truncated => finishReason == 'length';

  /// 组装发给 API 的消息体。
  ///
  /// [contentParts] 由调用方**异步**编码好（附件要读文件 + base64，不能塞进同步方法）：
  /// 传了就发多模态数组，否则 content 退化为纯文本字符串。
  ///
  /// 注意：带 `tool_calls` 的助手消息和 `tool` 结果消息必须保持字符串 content，
  /// 所以它们永远不该走到多模态分支。
  Map<String, dynamic> toApiMap({List<Map<String, dynamic>>? contentParts}) {
    final map = <String, dynamic>{
      'role': role,
    };
    map['content'] = (contentParts != null && contentParts.isNotEmpty)
        ? contentParts
        : content;

    if (toolCalls != null && toolCalls!.isNotEmpty) {
      map['tool_calls'] = toolCalls!.map((t) => t.toMap()).toList();
    }
    if (toolCallId != null) {
      map['tool_call_id'] = toolCallId;
    }
    return map;
  }
}

class ToolCall {
  final String id;
  final String name;
  final Map<String, dynamic> arguments;

  ToolCall({
    required this.id,
    required this.name,
    required this.arguments,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': 'function',
      'function': {
        'name': name,
        'arguments': jsonEncode(arguments),
      },
    };
  }

  factory ToolCall.fromMap(Map<String, dynamic> map) {
    final func = map['function'] as Map<String, dynamic>;
    return ToolCall(
      id: map['id'] as String,
      name: func['name'] as String,
      arguments: func['arguments'] is String
          ? Map<String, dynamic>.from(_parseJson(func['arguments'] as String))
          : Map<String, dynamic>.from(func['arguments'] as Map),
    );
  }

  /// 宽容版解析：结构不对就返回 null，**绝不抛异常**。
  ///
  /// 为什么需要它：厂商的**服务端工具**返回的 tool_call 可能长这样 ——
  /// `{"id":"call_1","type":"web_search","web_search":{...}}`，
  /// **没有 `function` 字段**。用 [fromMap] 会 `map['function'] as Map` 直接抛
  /// TypeError，把一次本来成功的回答变成报错弹窗。
  ///
  /// 这类工具由厂商服务端执行完再返回，客户端不需要也不应该去执行它，
  /// 所以丢掉是正确的处理（与流式路径的 `ToolCallAssembler.build()` 一致 ——
  /// 那边也会跳过没有名字的残缺分片）。
  static ToolCall? tryFromMap(dynamic raw) {
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    final func = map['function'];
    if (func is! Map) return null;
    final name = func['name'];
    if (name is! String || name.trim().isEmpty) return null;

    final id = map['id'];
    final args = func['arguments'];
    return ToolCall(
      id: id is String && id.isNotEmpty ? id : 'call_unknown',
      name: name,
      arguments: args is String
          ? Map<String, dynamic>.from(_parseJson(args))
          : (args is Map ? Map<String, dynamic>.from(args) : const {}),
    );
  }

  static dynamic _parseJson(String str) {
    try {
      return jsonDecode(str);
    } catch (_) {
      return {};
    }
  }
}
