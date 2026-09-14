import '../../../data/models/diary_entry.dart';

/// 一年的年报数据快照
///
/// 纯数据容器，不带任何 UI 逻辑 —— 让年报页只负责「怎么讲」，
/// 数字怎么来交给 `YearReportService`。
class YearSummary {
  final int year;

  /// 全年写的篇数
  final int entries;

  /// 全年写的总字数
  final int words;

  /// 全年有日记的天数
  final int activeDays;

  /// 全年任意一段最长的连续写作天数
  final int longestStreak;

  /// 最常在几点写作（0~23）；无数据为 null
  final int? peakHour;

  /// 全年最主要的心情 emoji；无数据为空串
  final String topMood;

  /// 上述心情出现的次数
  final int topMoodCount;

  /// 全年字数最多的那篇，用于「最值得重读」；无数据为 null
  final DiaryEntry? highlightEntry;

  const YearSummary({
    required this.year,
    required this.entries,
    required this.words,
    required this.activeDays,
    required this.longestStreak,
    this.peakHour,
    this.topMood = '',
    this.topMoodCount = 0,
    this.highlightEntry,
  });

  /// 是否完全没有任何数据（用来决定要不要显示年报入口）
  bool get isEmpty => entries == 0;

  /// 平均每篇多少字
  int get avgWordsPerEntry => entries == 0 ? 0 : words ~/ entries;

  /// 有日记的天数占全年的比例（0.0~1.0）
  double get activeRatio {
    final daysInYear = DateTime(year, 12, 31)
        .difference(DateTime(year, 1, 1))
        .inDays + 1;
    if (daysInYear <= 0) return 0;
    return (activeDays / daysInYear).clamp(0.0, 1.0);
  }

  /// 把 [peakHour] 说成人话时段
  String get peakHourLabel {
    final h = peakHour;
    if (h == null) return '';
    if (h < 6) return '凌晨 $h 点';
    if (h < 12) return '上午 $h 点';
    if (h < 14) return '中午 $h 点';
    if (h < 18) return '下午 $h 点';
    if (h < 23) return '晚上 $h 点';
    return '深夜 $h 点';
  }

  /// 把 [peakHour] 映射成一句有画面感的描述
  String get peakHourPoetic {
    final h = peakHour;
    if (h == null) return '你在一天里的任何时候都可能提笔';
    if (h < 6) return '夜色最深的时候，你还在写';
    if (h < 9) return '天刚亮，你就开始记下今天';
    if (h < 12) return '上午的光里，你习惯写下心事';
    if (h < 14) return '午间的空隙，被你用来写字';
    if (h < 18) return '午后，是你最常提笔的时辰';
    if (h < 22) return '入夜之后，笔尖才醒过来';
    return '深夜，是你与自己说话的时间';
  }
}
