import 'dart:convert';

class ChatMessage {
  final String role; // 'user', 'assistant', 'system', 'tool'
  final String content;
  final List<ToolCall>? toolCalls;
  final String? toolCallId;
  final String? toolName;
  final DateTime timestamp;

  ChatMessage({
    required this.role,
    required this.content,
    this.toolCalls,
    this.toolCallId,
    this.toolName,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toApiMap() {
    final map = <String, dynamic>{
      'role': role,
    };
    // content 始终作为字符串发送（某些 API 不接受 null 或缺失）
    map['content'] = content;
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

  static dynamic _parseJson(String str) {
    try {
      return _decodeJson(str);
    } catch (_) {
      return {};
    }
  }

  static dynamic _decodeJson(String str) {
    return jsonDecode(str);
  }
}
