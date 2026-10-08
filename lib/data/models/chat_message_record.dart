/// 聊天消息的持久化模型（对应 chat_messages 表）。
///
/// 只依赖 dart:convert：`tool_calls` / `attachments` 在数据层保持原始 JSON 字符串，
/// 由 features 层负责与业务模型（ChatMessage）互转，避免 data → features 的反向依赖。
library;

class ChatMessageRecord {
  final int? id;
  final int sessionId;
  final String role;
  final String content;
  final String toolCallsJson;
  final String toolCallId;
  final String toolName;
  final String attachmentsJson;
  final String status;

  /// 模型的思考过程（DeepSeek-R1 / Qwen3 / GLM 等的 `reasoning_content`）。
  /// 只用于展示，**绝不回传给 API** —— 多数厂商会因此报 400。
  final String reasoning;
  final DateTime createdAt;

  ChatMessageRecord({
    this.id,
    required this.sessionId,
    required this.role,
    this.content = '',
    this.toolCallsJson = emptyJsonArray,
    this.toolCallId = '',
    this.toolName = '',
    this.attachmentsJson = emptyJsonArray,
    this.status = statusSent,
    this.reasoning = '',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  static const String emptyJsonArray = '[]';

  // ── 消息状态 ──
  static const String statusSending = 'sending';
  static const String statusSent = 'sent';
  static const String statusFailed = 'failed';

  // ── 角色 ──
  static const String roleUser = 'user';
  static const String roleAssistant = 'assistant';
  static const String roleTool = 'tool';
  static const String roleSystem = 'system';

  ChatMessageRecord copyWith({
    int? id,
    int? sessionId,
    String? role,
    String? content,
    String? toolCallsJson,
    String? toolCallId,
    String? toolName,
    String? attachmentsJson,
    String? status,
    String? reasoning,
    DateTime? createdAt,
  }) {
    return ChatMessageRecord(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      role: role ?? this.role,
      content: content ?? this.content,
      toolCallsJson: toolCallsJson ?? this.toolCallsJson,
      toolCallId: toolCallId ?? this.toolCallId,
      toolName: toolName ?? this.toolName,
      attachmentsJson: attachmentsJson ?? this.attachmentsJson,
      status: status ?? this.status,
      reasoning: reasoning ?? this.reasoning,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'session_id': sessionId,
        'role': role,
        'content': content,
        'tool_calls': toolCallsJson,
        'tool_call_id': toolCallId,
        'tool_name': toolName,
        'attachments': attachmentsJson,
        'status': status,
        'reasoning': reasoning,
        'created_at': createdAt.toIso8601String(),
      };

  factory ChatMessageRecord.fromMap(Map<String, dynamic> map) {
    return ChatMessageRecord(
      id: map['id'] as int?,
      sessionId: (map['session_id'] as int?) ?? 0,
      role: _str(map['role'], roleUser),
      content: _str(map['content'], ''),
      toolCallsJson: _jsonOrArray(map['tool_calls']),
      toolCallId: _str(map['tool_call_id'], ''),
      toolName: _str(map['tool_name'], ''),
      attachmentsJson: _jsonOrArray(map['attachments']),
      status: _str(map['status'], statusSent),
      reasoning: _str(map['reasoning'], ''),
      createdAt: _date(map['created_at']),
    );
  }

  bool get isUser => role == roleUser;
  bool get isAssistant => role == roleAssistant;
  bool get isTool => role == roleTool;

  /// 是否有可展示的思考过程
  bool get hasReasoning => reasoning.trim().isNotEmpty;

  static String _str(dynamic v, String fallback) {
    if (v is String) return v;
    return fallback;
  }

  /// tool_calls / attachments 在库里存的是 JSON 文本；兼容 null / 空串
  static String _jsonOrArray(dynamic v) {
    if (v is String && v.trim().isNotEmpty) return v;
    return emptyJsonArray;
  }

  static DateTime _date(dynamic v) {
    if (v is String) {
      final parsed = DateTime.tryParse(v);
      if (parsed != null) return parsed;
    }
    return DateTime.now();
  }

  @override
  String toString() =>
      'ChatMessageRecord(id: $id, session: $sessionId, role: $role, status: $status)';
}
