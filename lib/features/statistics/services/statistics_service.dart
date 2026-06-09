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
}
