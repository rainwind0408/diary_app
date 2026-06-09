import '../models/achievement.dart';

class AchievementDefs {
  AchievementDefs._();

  // ── 写作成就 ──
  static const firstEntry = Achievement(
    id: 'first_entry',
    name: '萌芽',
    description: '写第一篇日记',
    icon: '🌱',
    category: AchievementCategory.writing,
  );
  static const entry10 = Achievement(
    id: 'entry_10',
    name: '成长',
    description: '写 10 篇日记',
    icon: '🌿',
    category: AchievementCategory.writing,
  );
  static const entry50 = Achievement(
    id: 'entry_50',
    name: '茂盛',
    description: '写 50 篇日记',
    icon: '🌳',
    category: AchievementCategory.writing,
  );
  static const entry100 = Achievement(
    id: 'entry_100',
    name: '参天',
    description: '写 100 篇日记',
    icon: '🌲',
    category: AchievementCategory.writing,
  );
  static const entry365 = Achievement(
    id: 'entry_365',
    name: '巅峰',
    description: '写 365 篇日记',
    icon: '🏔️',
    category: AchievementCategory.writing,
  );

  // ── 连续写作 ──
  static const streak3 = Achievement(
    id: 'streak_3',
    name: '初心',
    description: '连续写作 3 天',
    icon: '🔥',
    category: AchievementCategory.streak,
  );
  static const streak7 = Achievement(
    id: 'streak_7',
    name: '坚持',
    description: '连续写作 7 天',
    icon: '🔥',
    category: AchievementCategory.streak,
  );
  static const streak14 = Achievement(
    id: 'streak_14',
    name: '毅力',
    description: '连续写作 14 天',
    icon: '🔥',
    category: AchievementCategory.streak,
  );
  static const streak30 = Achievement(
    id: 'streak_30',
    name: '习惯',
    description: '连续写作 30 天',
    icon: '⭐',
    category: AchievementCategory.streak,
  );
  static const streak100 = Achievement(
    id: 'streak_100',
    name: '传奇',
    description: '连续写作 100 天',
    icon: '💎',
    category: AchievementCategory.streak,
  );

  // ── 功能使用 ──
  static const usePhoto = Achievement(
    id: 'use_photo',
    name: '摄影师',
    description: '在日记中添加图片',
    icon: '📸',
    category: AchievementCategory.feature,
  );
  static const useAudio = Achievement(
    id: 'use_audio',
    name: '录音师',
    description: '在日记中添加录音',
    icon: '🎤',
    category: AchievementCategory.feature,
  );
  static const useTag = Achievement(
    id: 'use_tag',
    name: '标签大师',
    description: '使用标签功能',
    icon: '🏷️',
    category: AchievementCategory.feature,
  );
  static const useMood = Achievement(
    id: 'use_mood',
    name: '心情达人',
    description: '使用心情系统记录心情',
    icon: '😊',
    category: AchievementCategory.feature,
  );
  static const useLock = Achievement(
    id: 'use_lock',
    name: '守护者',
    description: '加密一篇日记',
    icon: '🔒',
    category: AchievementCategory.feature,
  );

  // ── 特殊成就 ──
  static const nightOwl = Achievement(
    id: 'night_owl',
    name: '夜猫子',
    description: '在 22:00 后写日记',
    icon: '🌙',
    category: AchievementCategory.special,
  );
  static const earlyBird = Achievement(
    id: 'early_bird',
    name: '早起鸟',
    description: '在 6:00 前写日记',
    icon: '🌅',
    category: AchievementCategory.special,
  );
  static const longWriter = Achievement(
    id: 'long_writer',
    name: '长篇作家',
    description: '单篇日记超过 1000 字',
    icon: '📖',
    category: AchievementCategory.special,
  );
  static const totalWords100k = Achievement(
    id: 'total_words_100k',
    name: '笔耕不辍',
    description: '总字数超过 10 万',
    icon: '💯',
    category: AchievementCategory.special,
  );
  static const monthPerfect = Achievement(
    id: 'month_perfect',
    name: '全勤王',
    description: '某个月每天都写日记',
    icon: '👑',
    category: AchievementCategory.special,
  );

  // 所有成就定义
  static const List<Achievement> all = [
    // 写作
    firstEntry, entry10, entry50, entry100, entry365,
    // 连续写作
    streak3, streak7, streak14, streak30, streak100,
    // 功能使用
    usePhoto, useAudio, useTag, useMood, useLock,
    // 特殊
    nightOwl, earlyBird, longWriter, totalWords100k, monthPerfect,
  ];

  // 按分类获取
  static List<Achievement> getByCategory(AchievementCategory category) {
    return all.where((a) => a.category == category).toList();
  }

  // 根据 ID 查找
  static Achievement? findById(String id) {
    for (final a in all) {
      if (a.id == id) return a;
    }
    return null;
  }
}
