class DatabaseConstants {
  DatabaseConstants._();

  static const String dbName = 'diary.db';
  static const int dbVersion = 8;
  static const String tableDiaryEntries = 'diary_entries';
  static const String tableAchievements = 'achievements';

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
}
