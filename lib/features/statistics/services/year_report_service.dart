import '../../../data/models/diary_entry.dart';
import '../../review/models/year_summary.dart';
import 'statistics_service.dart';

/// 年报数据装配
///
/// 把「一年」需要的所有数字一次性并发取回，组装成一个 [YearSummary]。
///
/// 为什么不塞进 `StatisticsProvider`：那个 provider 管的是**回顾页仪表盘**
/// （近 7/14/30 天趋势 + 当月统计），而年报是**整年快照**，生命周期完全不同 ——
/// 年报只在用户点进去时才需要，没必要常驻内存，也不该因为切趋势天数被重算。
class YearReportService {
  YearReportService._();

  /// 装配某一年的年报数据
  ///
  /// 5 个查询并发跑；每个都是单条聚合 SQL，**不加载 entry 实体**
  /// （唯一例外是「最值得重读」那篇，只取 1 行且要正文做摘要）。
  static Future<YearSummary> build(int year) async {
    final results = await Future.wait([
      StatisticsService.getYearSummary(year),
      StatisticsService.getYearHourDistribution(year),
      StatisticsService.getTopMoodOfYear(year),
      StatisticsService.getLongestEntryOfYear(year),
      StatisticsService.getLongestStreakOfYear(year),
    ]);

    final summary = results[0] as ({int entries, int words, int activeDays});
    final hourDist = results[1] as Map<int, int>;
    final topMood = results[2] as ({String mood, int count})?;
    final longest = results[3] as DiaryEntry?;
    final longestStreak = results[4] as int;

    return YearSummary(
      year: year,
      entries: summary.entries,
      words: summary.words,
      activeDays: summary.activeDays,
      longestStreak: longestStreak,
      peakHour: _peakHour(hourDist),
      topMood: topMood?.mood ?? '',
      topMoodCount: topMood?.count ?? 0,
      highlightEntry: longest,
    );
  }

  /// 找出写作次数最多的小时；无数据返回 null
  static int? _peakHour(Map<int, int> dist) {
    if (dist.isEmpty) return null;
    int? bestHour;
    var best = -1;
    // 固定按 0..23 遍历，保证同样数据下结果稳定
    for (var h = 0; h < 24; h++) {
      final c = dist[h] ?? 0;
      if (c > best) {
        best = c;
        bestHour = h;
      }
    }
    return best > 0 ? bestHour : null;
  }
}
