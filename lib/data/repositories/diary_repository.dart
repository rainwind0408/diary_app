import '../database/database_helper.dart';
import '../database/database_constants.dart';
import '../models/diary_entry.dart';

class DiaryRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<int> insertEntry(DiaryEntry entry) async {
    final db = await _dbHelper.database;
    final map = entry.toMap();
    map.remove('id');
    return db.insert(DatabaseConstants.tableDiaryEntries, map);
  }

  Future<int> updateEntry(DiaryEntry entry) async {
    final db = await _dbHelper.database;
    return db.update(
      DatabaseConstants.tableDiaryEntries,
      entry.toMap()..remove('id'),
      where: '${DatabaseConstants.colId} = ?',
      whereArgs: [entry.id],
    );
  }

  Future<int> deleteEntry(int id) async {
    final db = await _dbHelper.database;
    return db.delete(
      DatabaseConstants.tableDiaryEntries,
      where: '${DatabaseConstants.colId} = ?',
      whereArgs: [id],
    );
  }

  Future<List<DiaryEntry>> getEntriesByDate(DateTime date) async {
    final db = await _dbHelper.database;
    final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final rows = await db.query(
      DatabaseConstants.tableDiaryEntries,
      where: "${DatabaseConstants.colCreatedAt} LIKE ?",
      whereArgs: ['$dateStr%'],
      orderBy: '${DatabaseConstants.colCreatedAt} DESC',
    );
    return rows.map((r) => DiaryEntry.fromMap(r)).toList();
  }

  Future<List<DiaryEntry>> getAllEntries() async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      DatabaseConstants.tableDiaryEntries,
      orderBy: '${DatabaseConstants.colCreatedAt} DESC',
    );
    return rows.map((r) => DiaryEntry.fromMap(r)).toList();
  }

  Future<DiaryEntry?> getEntryById(int id) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      DatabaseConstants.tableDiaryEntries,
      where: '${DatabaseConstants.colId} = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return DiaryEntry.fromMap(rows.first);
  }

  Future<int> getStreakDays() async {
    int streak = 0;
    DateTime date = DateTime.now();

    // 先检查今天是否有日记
    final todayEntries = await getEntriesByDate(date);
    if (todayEntries.isEmpty) {
      // 今天没写，从昨天开始计算
      date = date.subtract(const Duration(days: 1));
    }

    while (streak < 365) {
      final entries = await getEntriesByDate(date);
      if (entries.isEmpty) break;
      streak++;
      date = date.subtract(const Duration(days: 1));
    }
    return streak;
  }

  Future<Map<String, int>> getMonthlyStats(DateTime month) async {
    final db = await _dbHelper.database;
    final monthStr = '${month.year}-${month.month.toString().padLeft(2, '0')}';
    final rows = await db.rawQuery('''
      SELECT COUNT(*) as count, COALESCE(SUM(word_count), 0) as total_words
      FROM ${DatabaseConstants.tableDiaryEntries}
      WHERE ${DatabaseConstants.colCreatedAt} LIKE ?
    ''', ['$monthStr%']);
    if (rows.isEmpty) return {'count': 0, 'total_words': 0};
    return {
      'count': rows.first['count'] as int,
      'total_words': rows.first['total_words'] as int,
    };
  }

  Future<List<DiaryEntry>> getEntriesByTag(String tag) async {
    final db = await _dbHelper.database;
    final pattern = '%"$tag"%';
    final rows = await db.query(
      DatabaseConstants.tableDiaryEntries,
      where: '${DatabaseConstants.colTags} LIKE ?',
      whereArgs: [pattern],
      orderBy: '${DatabaseConstants.colCreatedAt} DESC',
    );
    return rows.map((r) => DiaryEntry.fromMap(r)).toList();
  }

  Future<List<DiaryEntry>> getEntriesByDateAndTag(DateTime date, String tag) async {
    final db = await _dbHelper.database;
    final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final pattern = '%"$tag"%';
    final rows = await db.query(
      DatabaseConstants.tableDiaryEntries,
      where: "${DatabaseConstants.colCreatedAt} LIKE ? AND ${DatabaseConstants.colTags} LIKE ?",
      whereArgs: ['$dateStr%', pattern],
      orderBy: '${DatabaseConstants.colCreatedAt} DESC',
    );
    return rows.map((r) => DiaryEntry.fromMap(r)).toList();
  }

  Future<Map<String, int>> getAllTags() async {
    final entries = await getAllEntries();
    final tagCount = <String, int>{};
    for (final entry in entries) {
      for (final tag in entry.tags) {
        tagCount[tag] = (tagCount[tag] ?? 0) + 1;
      }
    }
    return tagCount;
  }

  Future<Map<String, int>> getTagsByDate(DateTime date) async {
    final entries = await getEntriesByDate(date);
    final tagCount = <String, int>{};
    for (final entry in entries) {
      for (final tag in entry.tags) {
        tagCount[tag] = (tagCount[tag] ?? 0) + 1;
      }
    }
    return tagCount;
  }

  Future<List<DiaryEntry>> searchEntries(String keyword) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      DatabaseConstants.tableDiaryEntries,
      where: '${DatabaseConstants.colTitle} LIKE ? OR ${DatabaseConstants.colContent} LIKE ?',
      whereArgs: ['%$keyword%', '%$keyword%'],
      orderBy: '${DatabaseConstants.colCreatedAt} DESC',
    );
    return rows.map((r) => DiaryEntry.fromMap(r)).toList();
  }

  Future<Set<int>> getEntryDatesInMonth(int year, int month) async {
    final db = await _dbHelper.database;
    final monthStr = '$year-${month.toString().padLeft(2, '0')}';
    final rows = await db.query(
      DatabaseConstants.tableDiaryEntries,
      columns: [DatabaseConstants.colCreatedAt],
      where: "${DatabaseConstants.colCreatedAt} LIKE ?",
      whereArgs: ['$monthStr%'],
    );
    return rows.map((r) {
      final dt = DateTime.parse(r[DatabaseConstants.colCreatedAt] as String);
      return dt.day;
    }).toSet();
  }

  /// 整月「每天篇数 + 首条心情」的批量统计。
  ///
  /// 用一条 `GROUP BY substr(created_at, 1, 10)` 拿完整个月，
  /// 替代「先查有日记的日期、再逐天 getEntriesByDate」的 N+1 写法。
  /// 返回 `{日: (count: 篇数, mood: 当天首条日记的心情 emoji)}`，
  /// 心情可能为空字符串（当天日记未选心情）。
  Future<Map<int, ({int count, String mood})>> getMonthDayStats(
    int year,
    int month,
  ) async {
    final db = await _dbHelper.database;
    final monthStr = '$year-${month.toString().padLeft(2, '0')}';
    final rows = await db.rawQuery(
      '''
      SELECT substr(${DatabaseConstants.colCreatedAt}, 1, 10) AS day_key,
             COUNT(*) AS cnt,
             MAX(${DatabaseConstants.colMood}) AS mood
      FROM ${DatabaseConstants.tableDiaryEntries}
      WHERE ${DatabaseConstants.colCreatedAt} LIKE ?
      GROUP BY day_key
      ''',
      ['$monthStr%'],
    );

    final stats = <int, ({int count, String mood})>{};
    for (final row in rows) {
      final key = row['day_key'] as String?;
      if (key == null || key.length < 10) continue;
      final day = int.tryParse(key.substring(8, 10));
      if (day == null) continue;
      stats[day] = (
        count: (row['cnt'] as int?) ?? 0,
        mood: (row['mood'] as String?) ?? '',
      );
    }
    return stats;
  }

  /// 整月日记的图片路径，按时间倒序；「今天」的图片排在最前。
  ///
  /// 用于首页顶部封面图卡片的轮播。日记里的图片是画布绝对定位的贴图，
  /// 这里只取 `path` 字段，忽略 `dx/dy/rotation` 等排版数据。
  ///
  /// [todayFirst] 传 true 时，把 created_at 落在今天的图片提到列表首位；
  /// 今天没有图片则保持纯时间倒序。
  Future<List<String>> getMonthImagePaths(
    int year,
    int month, {
    bool todayFirst = true,
  }) async {
    final entries = await getEntriesByMonth(year, month);
    final today = DateTime.now();

    final todayPaths = <String>[];
    final otherPaths = <String>[];

    for (final entry in entries) {
      if (entry.isLocked || entry.images.isEmpty) continue;
      final isToday = entry.createdAt.year == today.year &&
          entry.createdAt.month == today.month &&
          entry.createdAt.day == today.day;
      for (final image in entry.images) {
        if (image.path.isEmpty) continue;
        if (todayFirst && isToday) {
          todayPaths.add(image.path);
        } else {
          otherPaths.add(image.path);
        }
      }
    }

    return [...todayPaths, ...otherPaths];
  }

  /// 整月日记，按创建时间倒序。
  ///
  /// 供日历 / 封面图这类「月度视图」使用，避免为了拿图片而 `getAllEntries()` 全表加载。
  Future<List<DiaryEntry>> getEntriesByMonth(int year, int month) async {
    final db = await _dbHelper.database;
    final monthStr = '$year-${month.toString().padLeft(2, '0')}';
    final rows = await db.query(
      DatabaseConstants.tableDiaryEntries,
      where: "${DatabaseConstants.colCreatedAt} LIKE ?",
      whereArgs: ['$monthStr%'],
      orderBy: '${DatabaseConstants.colCreatedAt} DESC',
    );
    return rows.map((r) => DiaryEntry.fromMap(r)).toList();
  }

  Future<void> updateLockStatus(int id, bool isLocked, String pinHash) async {
    final db = await _dbHelper.database;
    await db.update(
      DatabaseConstants.tableDiaryEntries,
      {
        DatabaseConstants.colIsLocked: isLocked ? 1 : 0,
        DatabaseConstants.colPinHash: pinHash,
      },
      where: '${DatabaseConstants.colId} = ?',
      whereArgs: [id],
    );
  }

  /// 心情分布统计：返回 {emoji: count}
  Future<Map<String, int>> getMoodStats() async {
    final entries = await getAllEntries();
    final moodCount = <String, int>{};
    for (final entry in entries) {
      if (entry.mood.isNotEmpty) {
        moodCount[entry.mood] = (moodCount[entry.mood] ?? 0) + 1;
      }
    }
    return moodCount;
  }

  /// 写作时间分布：按时间段统计
  Future<Map<String, int>> getTimeDistribution() async {
    final entries = await getAllEntries();
    final dist = {'早晨': 0, '下午': 0, '晚上': 0, '深夜': 0};
    for (final entry in entries) {
      final hour = entry.createdAt.hour;
      if (hour >= 6 && hour < 12) {
        dist['早晨'] = dist['早晨']! + 1;
      } else if (hour >= 12 && hour < 18) {
        dist['下午'] = dist['下午']! + 1;
      } else if (hour >= 18 && hour < 23) {
        dist['晚上'] = dist['晚上']! + 1;
      } else {
        dist['深夜'] = dist['深夜']! + 1;
      }
    }
    return dist;
  }

  /// 年度写作天数：返回有日记的日期集合
  Future<Set<String>> getYearlyEntryDates() async {
    final db = await _dbHelper.database;
    final now = DateTime.now();
    final start = DateTime(now.year - 1, now.month, now.day);
    final startStr = '${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}';
    final rows = await db.query(
      DatabaseConstants.tableDiaryEntries,
      columns: [DatabaseConstants.colCreatedAt],
      where: "${DatabaseConstants.colCreatedAt} >= ?",
      whereArgs: [startStr],
    );
    return rows.map((r) {
      final dt = DateTime.parse(r[DatabaseConstants.colCreatedAt] as String);
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    }).toSet();
  }
}
