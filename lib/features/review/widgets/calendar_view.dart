import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/repositories/diary_repository.dart';

/// 全屏日历视图（参考图6）
/// 月份选择器 + 甜甜圈统计图 + 彩色方格 + 每日标记
class CalendarView extends StatefulWidget {
  const CalendarView({super.key});

  @override
  State<CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends State<CalendarView> {
  DateTime _currentMonth = DateTime.now();
  final DiaryRepository _repository = DiaryRepository();
  Set<int> _entryDays = {};
  Map<int, String> _dayMoods = {};
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _loadMonthData();
  }

  Future<void> _loadMonthData() async {
    final generation = ++_loadGeneration;

    final entryDays = await _repository.getEntryDatesInMonth(
      _currentMonth.year,
      _currentMonth.month,
    );

    // Load moods for each day
    final dayMoods = <int, String>{};
    for (final day in entryDays) {
      final date = DateTime(_currentMonth.year, _currentMonth.month, day);
      final entries = await _repository.getEntriesByDate(date);
      if (entries.isNotEmpty && entries.first.mood.isNotEmpty) {
        dayMoods[day] = entries.first.mood;
      }
    }

    if (mounted && generation == _loadGeneration) {
      setState(() {
        _entryDays = entryDays;
        _dayMoods = dayMoods;
      });
    }
  }

  // 水彩色轮换
  static const List<Color> _dayColors = [
    AppColors.pink,
    AppColors.blue,
    AppColors.green,
    AppColors.yellow,
    AppColors.purple,
  ];

  // 励志语录
  static const List<String> _quotes = [
    '今天是新的开始',
    '每一天都值得记录',
    '写下你的故事',
    '生活需要仪式感',
    '记录美好瞬间',
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = isDark ? AppColors.darkAccentPink : AppColors.accentPink;
    final textColor = isDark ? AppColors.darkTitleText : AppColors.titleText;
    final subtleColor = isDark ? AppColors.darkSubtleText : AppColors.subtleText;
    final cardBg = isDark ? AppColors.darkCardBackground : AppColors.cardBackground;

    final year = _currentMonth.year;
    final month = _currentMonth.month;
    final firstDay = DateTime(year, month, 1);
    final lastDay = DateTime(year, month + 1, 0);
    final startWeekday = firstDay.weekday % 7;
    final today = DateTime.now();

    // 甜甜圈图数据
    final moodCount = <String, int>{};
    for (final mood in _dayMoods.values) {
      moodCount[mood] = (moodCount[mood] ?? 0) + 1;
    }

    // 励志语录（基于月份选择）
    final quote = _quotes[month % _quotes.length];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: isDark ? AppColors.darkCardShadow : AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 月份选择器 + 甜甜圈图
          Row(
            children: [
              // 月份导航
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_getMonthName(month)} $year',
                      style: AppTextStyles.handwritingTitle.copyWith(
                        color: textColor,
                        fontSize: 22,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _NavArrow(
                          onTap: () {
                            setState(() {
                              _currentMonth = DateTime(year, month - 1);
                            });
                            _loadMonthData();
                          },
                          color: subtleColor,
                        ),
                        const SizedBox(width: 12),
                        _NavArrow(
                          onTap: () {
                            final next = DateTime(year, month + 1);
                            if (!next.isAfter(DateTime.now())) {
                              setState(() => _currentMonth = next);
                              _loadMonthData();
                            }
                          },
                          color: subtleColor,
                          isForward: true,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // 甜甜圈统计图
              if (moodCount.isNotEmpty)
                SizedBox(
                  width: 80,
                  height: 80,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 25,
                      sections: _buildPieSections(moodCount),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // 彩色方格日历
          Row(
            children: ['日', '一', '二', '三', '四', '五', '六'].map((d) {
              return Expanded(
                child: Center(
                  child: Text(
                    d,
                    style: TextStyle(
                      fontSize: 11,
                      color: subtleColor.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1,
            ),
            itemCount: startWeekday + lastDay.day,
            itemBuilder: (context, index) {
              if (index < startWeekday) return const SizedBox.shrink();

              final day = index - startWeekday + 1;
              final date = DateTime(year, month, day);
              final isToday = date.year == today.year &&
                  date.month == today.month &&
                  date.day == today.day;
              final hasEntry = _entryDays.contains(day);
              final mood = _dayMoods[day];
              final dayColor = _dayColors[day % _dayColors.length];

              return Container(
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: hasEntry
                      ? dayColor.withValues(alpha: 0.35)
                      : dayColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: isToday
                      ? Border.all(color: accentColor, width: 1.5)
                      : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (mood != null)
                      Text(mood, style: const TextStyle(fontSize: 14))
                    else
                      Text(
                        '$day',
                        style: TextStyle(
                          fontSize: 12,
                          color: hasEntry ? textColor : subtleColor.withValues(alpha: 0.5),
                          fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    if (hasEntry && mood == null)
                      Container(
                        width: 4,
                        height: 4,
                        margin: const EdgeInsets.only(top: 2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: accentColor,
                        ),
                      ),
                  ],
                ),
              );
            },
          ),

          // 励志语录
          const SizedBox(height: 12),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                quote,
                style: TextStyle(
                  fontSize: 13,
                  color: accentColor,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<PieChartSectionData> _buildPieSections(Map<String, int> moodCount) {
    final colors = [
      AppColors.pink,
      AppColors.blue,
      AppColors.green,
      AppColors.yellow,
      AppColors.purple,
    ];
    final total = moodCount.values.fold(0, (sum, v) => sum + v);

    return moodCount.entries.toList().asMap().entries.map((entry) {
      final index = entry.key;
      final mood = entry.value;
      final percent = mood.value / total * 100;
      return PieChartSectionData(
        value: mood.value.toDouble(),
        title: '${percent.round()}%',
        titleStyle: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        color: colors[index % colors.length],
        radius: 30,
      );
    }).toList();
  }

  String _getMonthName(int month) {
    const names = [
      '', 'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return names[month];
  }
}

class _NavArrow extends StatelessWidget {
  final VoidCallback onTap;
  final Color color;
  final bool isForward;

  const _NavArrow({
    required this.onTap,
    required this.color,
    this.isForward = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(
          isForward ? Icons.chevron_right : Icons.chevron_left,
          size: 18,
          color: color,
        ),
      ),
    );
  }
}
