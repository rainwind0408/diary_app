class DatabaseConstants {
  DatabaseConstants._();

  static const String dbName = 'diary.db';
  static const int dbVersion = 11;
  static const String tableDiaryEntries = 'diary_entries';
  static const String tableAchievements = 'achievements';

  // ── AI 助手会话表（v9 新增）──
  static const String tableChatSessions = 'chat_sessions';
  static const String tableChatMessages = 'chat_messages';

  // ── diary_entries 列 ──
  static const String colId = 'id';
  static const String colTitle = 'title';
  static const String colContent = 'content';
  static const String colMood = 'mood';
  static const String colMoodIntensity = 'mood_intensity';
  static const String colMoodNote = 'mood_note';
  static const String colMoodLabel = 'mood_label';
  static const String colWordCount = 'word_count';
  static const String colCreatedAt = 'created_at';
  static const String colUpdatedAt = 'updated_at';
  static const String colIsLocked = 'is_locked';
  static const String colPinHash = 'pin_hash';
  static const String colTags = 'tags';
  static const String colImages = 'images';
  static const String colAudios = 'audios';
  static const String colStickers = 'stickers';

  // ── diary_entries 列（v11 新增）──
  /// 写这篇日记时的天气快照，如 `晴 23°C`。定位不可用时为空串。
  static const String colWeather = 'weather';

  /// 写这篇日记时的地点快照，如 `广东省深圳市福田区`。定位不可用时为空串。
  static const String colLocation = 'location';

  // ── chat_sessions 列 ──
  static const String colProviderId = 'provider_id';
  static const String colModel = 'model';
  static const String colIsPinned = 'is_pinned';
  static const String colMessageCount = 'message_count';
  static const String colLastMessage = 'last_message';

  // ── chat_messages 列 ──
  static const String colSessionId = 'session_id';
  static const String colRole = 'role';
  static const String colToolCalls = 'tool_calls';
  static const String colToolCallId = 'tool_call_id';
  static const String colToolName = 'tool_name';
  static const String colAttachments = 'attachments';
  static const String colStatus = 'status';

  // ── chat_messages 列（v10 新增）──
  /// 模型的思考过程（DeepSeek-R1 / Qwen3 / GLM 等的 reasoning_content）
  static const String colReasoning = 'reasoning';
}
