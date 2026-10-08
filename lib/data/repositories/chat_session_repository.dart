import '../database/database_constants.dart';
import '../database/database_helper.dart';
import '../models/chat_message_record.dart';
import '../models/chat_session.dart';

/// AI 助手会话与消息的仓储。
///
/// 说明：sqflite 默认不开启外键约束，因此删除会话时**手动先删消息**，
/// 不依赖 `ON DELETE CASCADE`，避免不同 SQLite 版本行为差异。
class ChatSessionRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // ─────────────────────────────────────────────
  // 会话
  // ─────────────────────────────────────────────

  /// 会话列表：置顶优先，其次按更新时间倒序
  Future<List<ChatSession>> getSessions() async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      DatabaseConstants.tableChatSessions,
      orderBy: '${DatabaseConstants.colIsPinned} DESC, '
          '${DatabaseConstants.colUpdatedAt} DESC, '
          '${DatabaseConstants.colId} DESC',
    );
    return rows.map((r) => ChatSession.fromMap(r)).toList();
  }

  Future<ChatSession?> getSessionById(int id) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      DatabaseConstants.tableChatSessions,
      where: '${DatabaseConstants.colId} = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return ChatSession.fromMap(rows.first);
  }

  /// 新建会话，返回带 id 的会话对象
  Future<ChatSession> createSession({
    String? title,
    String providerId = '',
    String model = '',
  }) async {
    final db = await _dbHelper.database;
    final session = ChatSession(
      title: (title == null || title.trim().isEmpty)
          ? ChatSession.defaultTitle
          : title.trim(),
      providerId: providerId,
      model: model,
    );
    final map = session.toMap()..remove('id');
    final id = await db.insert(
      DatabaseConstants.tableChatSessions,
      map,
    );
    return session.copyWith(id: id);
  }

  Future<void> renameSession(int id, String title) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return;
    final db = await _dbHelper.database;
    await db.update(
      DatabaseConstants.tableChatSessions,
      {DatabaseConstants.colTitle: trimmed},
      where: '${DatabaseConstants.colId} = ?',
      whereArgs: [id],
    );
  }

  Future<void> pinSession(int id, bool pinned) async {
    final db = await _dbHelper.database;
    await db.update(
      DatabaseConstants.tableChatSessions,
      {DatabaseConstants.colIsPinned: pinned ? 1 : 0},
      where: '${DatabaseConstants.colId} = ?',
      whereArgs: [id],
    );
  }

  /// 删除会话（连同其所有消息）
  Future<void> deleteSession(int id) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      await txn.delete(
        DatabaseConstants.tableChatMessages,
        where: '${DatabaseConstants.colSessionId} = ?',
        whereArgs: [id],
      );
      await txn.delete(
        DatabaseConstants.tableChatSessions,
        where: '${DatabaseConstants.colId} = ?',
        whereArgs: [id],
      );
    });
  }

  /// 清空所有会话与消息
  Future<void> clearAllSessions() async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      await txn.delete(DatabaseConstants.tableChatMessages);
      await txn.delete(DatabaseConstants.tableChatSessions);
    });
  }

  /// 更新会话的「最近活跃」信息（追加/删除消息后调用）
  Future<void> touchSession(
    int sessionId, {
    String? lastMessage,
    String? providerId,
    String? model,
  }) async {
    final db = await _dbHelper.database;
    final count = await getMessageCount(sessionId);

    final values = <String, Object?>{
      DatabaseConstants.colUpdatedAt: DateTime.now().toIso8601String(),
      DatabaseConstants.colMessageCount: count,
    };
    if (lastMessage != null) {
      values[DatabaseConstants.colLastMessage] = _preview(lastMessage);
    }
    if (providerId != null && providerId.isNotEmpty) {
      values[DatabaseConstants.colProviderId] = providerId;
    }
    if (model != null && model.isNotEmpty) {
      values[DatabaseConstants.colModel] = model;
    }

    await db.update(
      DatabaseConstants.tableChatSessions,
      values,
      where: '${DatabaseConstants.colId} = ?',
      whereArgs: [sessionId],
    );
  }

  // ─────────────────────────────────────────────
  // 消息
  // ─────────────────────────────────────────────

  /// 会话内的消息，按时间正序
  Future<List<ChatMessageRecord>> getMessages(int sessionId) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      DatabaseConstants.tableChatMessages,
      where: '${DatabaseConstants.colSessionId} = ?',
      whereArgs: [sessionId],
      orderBy: '${DatabaseConstants.colCreatedAt} ASC, '
          '${DatabaseConstants.colId} ASC',
    );
    return rows.map((r) => ChatMessageRecord.fromMap(r)).toList();
  }

  /// 追加一条消息，返回其 id
  Future<int> appendMessage(ChatMessageRecord message) async {
    final db = await _dbHelper.database;
    final map = message.toMap()..remove('id');
    return db.insert(DatabaseConstants.tableChatMessages, map);
  }

  Future<void> updateMessageContent(int id, String content) async {
    final db = await _dbHelper.database;
    await db.update(
      DatabaseConstants.tableChatMessages,
      {DatabaseConstants.colContent: content},
      where: '${DatabaseConstants.colId} = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateMessageStatus(int id, String status) async {
    final db = await _dbHelper.database;
    await db.update(
      DatabaseConstants.tableChatMessages,
      {DatabaseConstants.colStatus: status},
      where: '${DatabaseConstants.colId} = ?',
      whereArgs: [id],
    );
  }

  /// 同时更新内容与状态（流式结束后收尾用）
  Future<void> updateMessageContentAndStatus(
    int id,
    String content,
    String status,
  ) async {
    final db = await _dbHelper.database;
    await db.update(
      DatabaseConstants.tableChatMessages,
      {
        DatabaseConstants.colContent: content,
        DatabaseConstants.colStatus: status,
      },
      where: '${DatabaseConstants.colId} = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteMessage(int id) async {
    final db = await _dbHelper.database;
    await db.delete(
      DatabaseConstants.tableChatMessages,
      where: '${DatabaseConstants.colId} = ?',
      whereArgs: [id],
    );
  }

  /// 删除某条消息之后的所有消息（「重新生成」用）。
  ///
  /// 按自增 id 比较而不是时间戳：同一毫秒内写入的多条消息（如
  /// assistant + 若干 tool）时间戳可能完全相同，用 `createdAt >` 会漏删。
  Future<void> deleteMessagesAfterId(int sessionId, int messageId) async {
    final db = await _dbHelper.database;
    await db.delete(
      DatabaseConstants.tableChatMessages,
      where: '${DatabaseConstants.colSessionId} = ? AND '
          '${DatabaseConstants.colId} > ?',
      whereArgs: [sessionId, messageId],
    );
  }

  /// 所有消息的 attachments 原始 JSON（清理孤儿附件文件用）。
  ///
  /// 这里只返回原始字符串，不做解析 —— 解析成业务模型是 features 层的事，
  /// 数据层不该反向依赖它。
  Future<List<String>> getAllAttachmentsJson() async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      DatabaseConstants.tableChatMessages,
      columns: [DatabaseConstants.colAttachments],
    );
    return rows
        .map((r) => (r[DatabaseConstants.colAttachments] as String?) ?? '')
        .where((s) {
          final t = s.trim();
          return t.isNotEmpty && t != ChatMessageRecord.emptyJsonArray;
        })
        .toList();
  }

  Future<int> getMessageCount(int sessionId) async {    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM ${DatabaseConstants.tableChatMessages} '
      'WHERE ${DatabaseConstants.colSessionId} = ?',
      [sessionId],
    );
    final value = result.first['c'];
    if (value is int) return value;
    return 0;
  }

  /// 会话最后一条消息的预览文本（列表页展示用）
  Future<String> getLastMessagePreview(int sessionId) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      DatabaseConstants.tableChatMessages,
      columns: [DatabaseConstants.colContent],
      where: '${DatabaseConstants.colSessionId} = ?',
      whereArgs: [sessionId],
      orderBy: '${DatabaseConstants.colCreatedAt} DESC, '
          '${DatabaseConstants.colId} DESC',
      limit: 1,
    );
    if (rows.isEmpty) return '';
    return _preview((rows.first[DatabaseConstants.colContent] as String?) ?? '');
  }

  static String _preview(String text, {int maxLength = 30}) {
    final cleaned = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    final runes = cleaned.runes.toList();
    if (runes.length <= maxLength) return cleaned;
    return '${String.fromCharCodes(runes.take(maxLength))}…';
  }
}
