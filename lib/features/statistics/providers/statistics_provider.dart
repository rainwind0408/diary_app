import 'package:flutter/foundation.dart';
import '../services/statistics_service.dart';

class StatisticsProvider extends ChangeNotifier {
  Map<String, int> _moodDistribution = {};
  Map<String, List<String>> _moodTrend = {};
  Map<String, int> _wordCountTrend = {};
  Map<String, int> _tagCloud = {};
  Map<String, int> _timeDistribution = {};
  Map<String, int> _monthlyStats = {};
  Set<String> _yearlyDates = {};
  int _streakDays = 0;
  bool _loading = true;
  int _trendDays = 7;

  Map<String, int> get moodDistribution => _moodDistribution;
  Map<String, List<String>> get moodTrend => _moodTrend;
  Map<String, int> get wordCountTrend => _wordCountTrend;
  Map<String, int> get tagCloud => _tagCloud;
  Map<String, int> get timeDistribution => _timeDistribution;
  Map<String, int> get monthlyStats => _monthlyStats;
  Set<String> get yearlyDates => _yearlyDates;
  int get streakDays => _streakDays;
  bool get loading => _loading;
  int get trendDays => _trendDays;

  Future<void> loadStatistics() async {
    _loading = true;
    notifyListeners();

    try {
      final results = await Future.wait([
        StatisticsService.getMoodDistribution(),
        StatisticsService.getMoodTrend(_trendDays),
        StatisticsService.getWordCountTrend(_trendDays),
        StatisticsService.getTagCloud(),
        StatisticsService.getTimeDistribution(),
        StatisticsService.getMonthlyStats(DateTime.now()),
        StatisticsService.getYearlyEntryDates(),
        StatisticsService.getStreakDays(),
      ]);

      _moodDistribution = results[0] as Map<String, int>;
      _moodTrend = results[1] as Map<String, List<String>>;
      _wordCountTrend = results[2] as Map<String, int>;
      _tagCloud = results[3] as Map<String, int>;
      _timeDistribution = results[4] as Map<String, int>;
      _monthlyStats = results[5] as Map<String, int>;
      _yearlyDates = results[6] as Set<String>;
      _streakDays = results[7] as int;
    } catch (e) {
      // 出错时保留空数据
    }

    _loading = false;
    notifyListeners();
  }

  Future<void> setTrendDays(int days) async {
    if (days == _trendDays) return;
    _trendDays = days;

    final results = await Future.wait([
      StatisticsService.getMoodTrend(days),
      StatisticsService.getWordCountTrend(days),
    ]);
    _moodTrend = results[0] as Map<String, List<String>>;
    _wordCountTrend = results[1] as Map<String, int>;
    notifyListeners();
  }
}
