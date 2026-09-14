import '../../../data/models/diary_entry.dart';
import '../../../data/repositories/diary_repository.dart';

class StatisticsService {
  StatisticsService._();

  static final _repo = DiaryRepository();

  /// 心情分布统计：{emoji: count}
  static Future<Map<String, int>> getMoodDistribution() {
    return _repo.getMoodStats();
  }

  /// 心情趋势：最近 N 天每天的心情 emoji 列表
  static Future<Map<String, List<String>>> getMoodTrend(int days) async {
    final now = DateTime.now();
    final dates = List.generate(days, (i) => now.subtract(Duration(days: days - 1 - i)));
    final entriesList = await Future.wait(
      dates.map((date) => _repo.getEntriesByDate(date)),
    );

    final result = <String, List<String>>{};
    for (int i = 0; i < days; i++) {
      final key = '${dates[i].month}/${dates[i].day}';
      result[key] = entriesList[i]
          .where((e) => e.mood.isNotEmpty)
          .map((e) => e.mood)
          .toList();
    }
    return result;
  }

  /// 字数趋势：最近 N 天每天的总字数
  static Future<Map<String, int>> getWordCountTrend(int days) async {
    final now = DateTime.now();
    final dates = List.generate(days, (i) => now.subtract(Duration(days: days - 1 - i)));
    final entriesList = await Future.wait(
      dates.map((date) => _repo.getEntriesByDate(date)),
    );

    final result = <String, int>{};
    for (int i = 0; i < days; i++) {
      final key = '${dates[i].month}/${dates[i].day}';
      result[key] = entriesList[i].fold(0, (sum, e) => sum + e.wordCount);
    }
    return result;
  }

  /// 标签云数据：{tag: count}
  static Future<Map<String, int>> getTagCloud() {
    return _repo.getAllTags();
  }

  /// 写作时间分布：{时段: count}
  static Future<Map<String, int>> getTimeDistribution() {
    return _repo.getTimeDistribution();
  }

  /// 月度统计：{count: N, total_words: N}
  static Future<Map<String, int>> getMonthlyStats(DateTime month) {
    return _repo.getMonthlyStats(month);
  }

  /// 年度写作日期集合
  static Future<Set<String>> getYearlyEntryDates() {
    return _repo.getYearlyEntryDates();
  }

  /// 连续写作天数
  static Future<int> getStreakDays() {
    return _repo.getStreakDays();
  }

  // ── 年报所需（全部按年聚合，不加载 entry 实体）──

  /// 某年的篇数 / 字数 / 有日记的天数
  static Future<({int entries, int words, int activeDays})> getYearSummary(
    int year,
  ) {
    return _repo.getYearSummary(year);
  }

  /// 某年的小时分布 {0..23: count}
  static Future<Map<int, int>> getYearHourDistribution(int year) {
    return _repo.getYearHourDistribution(year);
  }

  /// 某年最主要的心情
  static Future<({String mood, int count})?> getTopMoodOfYear(int year) {
    return _repo.getTopMoodOfYear(year);
  }

  /// 某年字数最多的那篇日记（用于「最值得重读」）
  static Future<DiaryEntry?> getLongestEntryOfYear(int year) {
    return _repo.getLongestEntryOfYear(year);
  }

  /// 某年任意一段最长的连续写作天数
  static Future<int> getLongestStreakOfYear(int year) {
    return _repo.getLongestStreakOfYear(year);
  }

  /// 某年每天的字数与心情，供星座图绘制
  static Future<Map<int, ({int words, String mood})>> getYearDailyStats(
    int year,
  ) {
    return _repo.getYearDailyStats(year);
  }
}
