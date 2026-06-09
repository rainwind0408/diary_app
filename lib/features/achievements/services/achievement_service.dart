import '../models/achievement.dart';
import '../data/achievement_defs.dart';

class AchievementService {
  AchievementService._();

  /// 检查并返回新解锁的成就
  static List<Achievement> checkAndUnlock({
    required int totalEntries,
    required int streakDays,
    required Map<String, int> featureUsage,
    required Set<String> alreadyUnlocked,
    int? newEntryWordCount,
    int? newEntryHour,
    bool? newEntryHasMood,
  }) {
    final newAchievements = <Achievement>[];

    for (final def in AchievementDefs.all) {
      if (alreadyUnlocked.contains(def.id)) continue;

      bool unlocked = false;

      switch (def.id) {
        // ── 写作成就 ──
        case 'first_entry':
          unlocked = totalEntries >= 1;
          break;
        case 'entry_10':
          unlocked = totalEntries >= 10;
          break;
        case 'entry_50':
          unlocked = totalEntries >= 50;
          break;
        case 'entry_100':
          unlocked = totalEntries >= 100;
          break;
        case 'entry_365':
          unlocked = totalEntries >= 365;
          break;

        // ── 连续写作 ──
        case 'streak_3':
          unlocked = streakDays >= 3;
          break;
        case 'streak_7':
          unlocked = streakDays >= 7;
          break;
        case 'streak_14':
          unlocked = streakDays >= 14;
          break;
        case 'streak_30':
          unlocked = streakDays >= 30;
          break;
        case 'streak_100':
          unlocked = streakDays >= 100;
          break;

        // ── 功能使用 ──
        case 'use_photo':
          unlocked = (featureUsage['photo'] ?? 0) > 0;
          break;
        case 'use_audio':
          unlocked = (featureUsage['audio'] ?? 0) > 0;
          break;
        case 'use_tag':
          unlocked = (featureUsage['tag'] ?? 0) > 0;
          break;
        case 'use_mood':
          unlocked = newEntryHasMood == true;
          break;
        case 'use_lock':
          unlocked = (featureUsage['lock'] ?? 0) > 0;
          break;

        // ── 特殊成就 ──
        case 'night_owl':
          unlocked = newEntryHour != null && newEntryHour >= 22;
          break;
        case 'early_bird':
          unlocked = newEntryHour != null && newEntryHour < 6;
          break;
        case 'long_writer':
          unlocked = newEntryWordCount != null && newEntryWordCount >= 1000;
          break;
        case 'total_words_100k':
          unlocked = (featureUsage['total_words'] ?? 0) >= 100000;
          break;
        case 'month_perfect':
          unlocked = featureUsage['month_perfect'] == 1;
          break;
      }

      if (unlocked) {
        newAchievements.add(def.copyWith(unlockedAt: DateTime.now()));
      }
    }

    return newAchievements;
  }
}
