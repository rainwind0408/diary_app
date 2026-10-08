/// AI 助手会话模型（持久化层，只依赖 dart:convert）
library;

class ChatSession {
  final int? id;
  final String title;
  final String providerId;
  final String model;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isPinned;
  final int messageCount;
  final String lastMessage;

  ChatSession({
    this.id,
    this.title = defaultTitle,
    this.providerId = '',
    this.model = '',
    DateTime? createdAt,
    DateTime? updatedAt,
    this.isPinned = false,
    this.messageCount = 0,
    this.lastMessage = '',
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  static const String defaultTitle = '新会话';

  /// 会话标题最大长度
  static const int titleMaxLength = 12;

  ChatSession copyWith({
    int? id,
    String? title,
    String? providerId,
    String? model,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isPinned,
    int? messageCount,
    String? lastMessage,
  }) {
    return ChatSession(
      id: id ?? this.id,
      title: title ?? this.title,
      providerId: providerId ?? this.providerId,
      model: model ?? this.model,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isPinned: isPinned ?? this.isPinned,
      messageCount: messageCount ?? this.messageCount,
      lastMessage: lastMessage ?? this.lastMessage,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'provider_id': providerId,
        'model': model,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'is_pinned': isPinned ? 1 : 0,
        'message_count': messageCount,
        'last_message': lastMessage,
      };

  factory ChatSession.fromMap(Map<String, dynamic> map) {
    return ChatSession(
      id: map['id'] as int?,
      title: _str(map['title'], defaultTitle),
      providerId: _str(map['provider_id'], ''),
      model: _str(map['model'], ''),
      createdAt: _date(map['created_at']),
      updatedAt: _date(map['updated_at']),
      isPinned: (map['is_pinned'] as int?) == 1,
      messageCount: (map['message_count'] as int?) ?? 0,
      lastMessage: _str(map['last_message'], ''),
    );
  }

  /// 由首条用户消息自动生成标题：去掉换行、截断到 [titleMaxLength] 字
  static String titleFromMessage(String content) {
    final cleaned = content.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (cleaned.isEmpty) return defaultTitle;
    // 按字符（rune）截断，避免切断 emoji
    final runes = cleaned.runes.toList();
    if (runes.length <= titleMaxLength) return cleaned;
    return '${String.fromCharCodes(runes.take(titleMaxLength))}…';
  }

  static String _str(dynamic v, String fallback) {
    if (v is String && v.isNotEmpty) return v;
    return fallback;
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
      'ChatSession(id: $id, title: $title, pinned: $isPinned, count: $messageCount)';
}
