import '../models/achievement.dart';

/// 成长花园 / 成就时间轴 所需的排序与进度推算逻辑
///
/// 抽成独立服务而非塞进 Widget，是为了让这些纯函数可被单测覆盖，
/// 也避免 Widget 文件里混入业务规则。
class GardenArranger {
  GardenArranger._();

  /// 花园排布顺序：已解锁优先（最新解锁的排在最前），未解锁在后
  static List<Achievement> arrange(List<Achievement> achievements) {
    final sorted = [...achievements];
    sorted.sort((a, b) {
      if (a.isUnlocked != b.isUnlocked) return a.isUnlocked ? -1 : 1;
      final au = a.unlockedAt;
      final bu = b.unlockedAt;
      if (au != null && bu != null) return bu.compareTo(au);
      return a.id.compareTo(b.id);
    });
    return sorted;
  }

  /// 时间轴顺序：已解锁成就按解锁时间正序（最早的在前）
  static List<Achievement> timelineOrder(List<Achievement> achievements) {
    final unlocked = achievements
        .where((a) => a.isUnlocked && a.unlockedAt != null)
        .toList();
    unlocked.sort((a, b) => a.unlockedAt!.compareTo(b.unlockedAt!));
    return unlocked;
  }

  /// 按年月分组（用于时间轴的分段标题），返回有序的 (年月, 成就列表)
  static List<({int year, int month, List<Achievement> items})> groupByMonth(
    List<Achievement> timeline,
  ) {
    // timeline 已按时间正序，这里只需顺序分段
    final groups = <({int year, int month, List<Achievement> items})>[];
    for (final a in timeline) {
      final at = a.unlockedAt!;
      if (groups.isNotEmpty &&
          groups.last.year == at.year &&
          groups.last.month == at.month) {
        groups.last.items.add(a);
      } else {
        groups.add((year: at.year, month: at.month, items: [a]));
      }
    }
    return groups;
  }

  /// 下一个可争取的成就
  ///
  /// 成就定义按门槛递增排列，因此第一个未解锁的即为当前目标。
  static Achievement? nextGoal(List<Achievement> achievements) {
    for (final a in achievements) {
      if (!a.isUnlocked) return a;
    }
    return null;
  }

  /// 距下一个成就的进度（0.0~1.0）；无法数值化的成就返回 null
  static double? goalProgress(
    Achievement goal, {
    required int totalEntries,
    required int streakDays,
    required Map<String, int> featureUsage,
  }) {
    final target = targetValue(goal);
    if (target == null || target <= 0) return null;

    final current = currentValue(
      goal,
      totalEntries: totalEntries,
      streakDays: streakDays,
      featureUsage: featureUsage,
    );
    if (current == null) return null;
    return (current / target).clamp(0.0, 1.0);
  }

  /// 距离目标还差多少（用于「再坚持 N 天」文案）；无法估算返回 null
  static int? remainingToGoal(
    Achievement goal, {
    required int totalEntries,
    required int streakDays,
    required Map<String, int> featureUsage,
  }) {
    final target = targetValue(goal);
    if (target == null) return null;
    final current = currentValue(
      goal,
      totalEntries: totalEntries,
      streakDays: streakDays,
      featureUsage: featureUsage,
    );
    if (current == null) return null;
    return (target - current).clamp(0, target);
  }

  /// 成就对应的数值门槛
  static int? targetValue(Achievement a) {
    switch (a.id) {
      case 'first_entry':
        return 1;
      case 'entry_10':
        return 10;
      case 'entry_50':
        return 50;
      case 'entry_100':
        return 100;
      case 'entry_365':
        return 365;
      case 'streak_3':
        return 3;
      case 'streak_7':
        return 7;
      case 'streak_14':
        return 14;
      case 'streak_30':
        return 30;
      case 'streak_100':
        return 100;
      case 'streak_365':
        return 365;
      case 'total_words_100k':
        return 100000;
      default:
        return null;
    }
  }

  /// 用户在某成就维度上的当前值
  static int? currentValue(
    Achievement a, {
    required int totalEntries,
    required int streakDays,
    required Map<String, int> featureUsage,
  }) {
    if (a.category == AchievementCategory.writing) return totalEntries;
    if (a.category == AchievementCategory.streak) return streakDays;
    final key = featureKey(a.id);
    if (key != null) return featureUsage[key] ?? 0;
    return null;
  }

  static String? featureKey(String id) {
    switch (id) {
      case 'use_photo':
        return 'photo';
      case 'use_audio':
        return 'audio';
      case 'use_tag':
        return 'tag';
      case 'use_lock':
        return 'lock';
      case 'total_words_100k':
        return 'total_words';
      case 'month_perfect':
        return 'month_perfect';
      default:
        return null;
    }
  }

  static String categoryLabel(AchievementCategory c) {
    switch (c) {
      case AchievementCategory.writing:
        return '写作';
      case AchievementCategory.streak:
        return '连续';
      case AchievementCategory.feature:
        return '功能';
      case AchievementCategory.special:
        return '特殊';
    }
  }

  /// 进度文案：能数值化的给数字，不能的返回成就描述
  static String progressLabel(
    Achievement goal, {
    required int totalEntries,
    required int streakDays,
    required Map<String, int> featureUsage,
  }) {
    final target = targetValue(goal);
    final current = currentValue(
      goal,
      totalEntries: totalEntries,
      streakDays: streakDays,
      featureUsage: featureUsage,
    );
    if (target != null && current != null) {
      return '$current / $target';
    }
    return goal.description;
  }
}
