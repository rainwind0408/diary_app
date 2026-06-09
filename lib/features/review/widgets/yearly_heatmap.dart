import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';

class YearlyHeatmap extends StatelessWidget {
  final Set<String> entryDates;

  const YearlyHeatmap({super.key, required this.entryDates});

  static const double _cellSize = 12;
  static const double _cellGap = 3;
  static const List<String> _monthLabels = [
    '1月', '2月', '3月', '4月', '5月', '6月',
    '7月', '8月', '9月', '10月', '11月', '12月',
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final goldColor = isDark ? AppColors.darkGoldAccent : AppColors.goldAccent;
    final subtleColor = isDark ? AppColors.darkSubtleText : AppColors.subtleText;
    final bgColor = isDark ? AppColors.darkCardBackground : AppColors.cardBackground;
    final emptyColor = isDark
        ? AppColors.darkCardBackgroundAlt.withValues(alpha: 0.5)
        : AppColors.cardBackgroundAlt;

    final now = DateTime.now();
    // 从一年前的周日开始
    final endDate = now;
    final startDate = DateTime(now.year - 1, now.month, now.day);
    // 找到 startDate 所在周的周日
    final startSunday = startDate.subtract(Duration(days: startDate.weekday % 7));

    // 生成所有周
    final weeks = <List<DateTime>>[];
    var current = startSunday;
    while (current.isBefore(endDate) || current.isAtSameMomentAs(endDate)) {
      final week = List.generate(7, (i) => current.add(Duration(days: i)));
      weeks.add(week);
      current = current.add(const Duration(days: 7));
    }

    // 计算月份标签位置
    final monthPositions = <int, String>{};
    for (int w = 0; w < weeks.length; w++) {
      final firstDay = weeks[w].first;
      if (firstDay.day <= 7 && firstDay.isAfter(startDate)) {
        monthPositions[w] = _monthLabels[firstDay.month - 1];
      }
    }

    final totalDays = entryDates.length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: isDark ? AppColors.darkCardShadow : AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '年度概览',
                style: AppTextStyles.cardTitle.copyWith(
                  color: isDark ? AppColors.darkTitleText : AppColors.titleText,
                ),
              ),
              const Spacer(),
              Text(
                '共 $totalDays 天',
                style: AppTextStyles.label.copyWith(
                  color: subtleColor.withValues(alpha: 0.7),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 月份标签
          SizedBox(
            height: 16,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: weeks.length * (_cellSize + _cellGap),
                child: Stack(
                  children: monthPositions.entries.map((entry) {
                    return Positioned(
                      left: entry.key * (_cellSize + _cellGap),
                      child: Text(
                        entry.value,
                        style: TextStyle(fontSize: 9, color: subtleColor),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          // 热力图网格
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 星期标签
                Column(
                  children: List.generate(7, (i) {
                    final labels = ['日', '一', '二', '三', '四', '五', '六'];
                    return Container(
                      width: 16,
                      height: _cellSize + _cellGap,
                      alignment: Alignment.center,
                      child: i % 2 == 1
                          ? Text(
                              labels[i],
                              style: TextStyle(
                                fontSize: 9,
                                color: subtleColor.withValues(alpha: 0.5),
                              ),
                            )
                          : null,
                    );
                  }),
                ),
                // 格子
                ...weeks.map((week) {
                  return Column(
                    children: week.map((date) {
                      final dateStr =
                          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                      final hasEntry = entryDates.contains(dateStr);
                      final isFuture = date.isAfter(endDate);

                      return Container(
                        width: _cellSize,
                        height: _cellSize,
                        margin: const EdgeInsets.only(
                          right: _cellGap,
                          bottom: _cellGap,
                        ),
                        decoration: BoxDecoration(
                          color: isFuture
                              ? Colors.transparent
                              : hasEntry
                                  ? goldColor.withValues(alpha: 0.8)
                                  : emptyColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      );
                    }).toList(),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // 图例
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text('少', style: TextStyle(fontSize: 9, color: subtleColor)),
              const SizedBox(width: 4),
              ...List.generate(4, (i) {
                final opacity = 0.2 + i * 0.2;
                return Container(
                  width: _cellSize,
                  height: _cellSize,
                  margin: const EdgeInsets.only(left: 2),
                  decoration: BoxDecoration(
                    color: goldColor.withValues(alpha: opacity),
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              }),
              const SizedBox(width: 4),
              Text('多', style: TextStyle(fontSize: 9, color: subtleColor)),
            ],
          ),
        ],
      ),
    );
  }
}
