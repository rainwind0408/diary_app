import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../../../data/database/database_helper.dart';
import '../../../data/database/database_constants.dart';
import '../models/achievement.dart';
import '../data/achievement_defs.dart';
import '../services/achievement_service.dart';

class AchievementProvider extends ChangeNotifier {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // 已解锁的成就（id → 解锁时间）
  Map<String, DateTime> _unlockedMap = {};
  // 今日新解锁
  List<Achievement> _unlockedToday = [];
  bool _loading = true;

  List<Achievement> get unlockedToday => _unlockedToday;
  bool get loading => _loading;

  int get unlockedCount => _unlockedMap.length;
  int get totalCount => AchievementDefs.all.length;

  /// 获取完整成就列表（合并定义 + 解锁状态）
  List<Achievement> get achievements {
    return AchievementDefs.all.map((def) {
      final unlockedAt = _unlockedMap[def.id];
      return def.copyWith(unlockedAt: unlockedAt);
    }).toList();
  }

  /// 获取指定分类的成就
  List<Achievement> getByCategory(AchievementCategory category) {
    return achievements.where((a) => a.category == category).toList();
  }

  /// 从数据库加载已解锁的成就
  Future<void> loadAchievements() async {
    _loading = true;
    notifyListeners();

    try {
      final db = await _dbHelper.database;
      final rows = await db.query(DatabaseConstants.tableAchievements);

      _unlockedMap = {};
      for (final row in rows) {
        final id = row['id'] as String;
        final unlockedAt = row['unlocked_at'] as String?;
        if (unlockedAt != null) {
          _unlockedMap[id] = DateTime.parse(unlockedAt);
        }
      }
    } catch (e) {
      _unlockedMap = {};
    }

    _loading = false;
    notifyListeners();
  }

  /// 检查并解锁新成就
  Future<List<Achievement>> checkAndUnlock({
    required int totalEntries,
    required int streakDays,
    required Map<String, int> featureUsage,
    int? newEntryWordCount,
    int? newEntryHour,
    bool? newEntryHasMood,
  }) async {
    final newAchievements = AchievementService.checkAndUnlock(
      totalEntries: totalEntries,
      streakDays: streakDays,
      featureUsage: featureUsage,
      alreadyUnlocked: _unlockedMap.keys.toSet(),
      newEntryWordCount: newEntryWordCount,
      newEntryHour: newEntryHour,
      newEntryHasMood: newEntryHasMood,
    );

    if (newAchievements.isEmpty) return [];

    // 保存到数据库
    final db = await _dbHelper.database;
    final now = DateTime.now();
    for (final achievement in newAchievements) {
      await db.insert(
        DatabaseConstants.tableAchievements,
        {
          'id': achievement.id,
          'unlocked_at': now.toIso8601String(),
          'is_read': 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      _unlockedMap[achievement.id] = now;
    }

    _unlockedToday = List.from(newAchievements);
    notifyListeners();
    return List.from(newAchievements);
  }

  /// 标记成就为已读
  Future<void> markAsRead(String achievementId) async {
    final db = await _dbHelper.database;
    await db.update(
      DatabaseConstants.tableAchievements,
      {'is_read': 1},
      where: 'id = ?',
      whereArgs: [achievementId],
    );

    _unlockedToday.removeWhere((a) => a.id == achievementId);
    notifyListeners();
  }

  /// 清除今日新解锁列表
  void clearUnlockedToday() {
    _unlockedToday = [];
    notifyListeners();
  }
}
