import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';

class WritingHeatmap extends StatelessWidget {
  final Set<String> entryDates; // ISO date strings like "2026-06-03"

  const WritingHeatmap({super.key, required this.entryDates});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final goldColor = isDark ? AppColors.darkAccentPink : AppColors.accentPink;
    final subtleColor = isDark ? AppColors.darkSubtleText : AppColors.subtleText;
    final bgColor = isDark ? AppColors.darkCardBackground : AppColors.cardBackground;
    final borderColor = isDark ? AppColors.darkDividerLine : AppColors.dividerLine;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Build 53 weeks x 7 days grid (past year)
    final weeks = _buildWeeks(today);

    // Count stats
    final totalDays = entryDates.length;
    final currentStreak = _calcCurrentStreak(today);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.grid_on, size: 18, color: goldColor),
              const SizedBox(width: 8),
              Text(
                '写作热力图',
                style: AppTextStyles.cardTitle.copyWith(
                  color: isDark ? AppColors.darkTitleText : AppColors.titleText,
                ),
              ),
              const Spacer(),
              Text(
                '过去一年',
                style: AppTextStyles.label.copyWith(color: subtleColor),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Heatmap grid
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Weekday labels
                Column(
                  children: List.generate(7, (dayIndex) {
                    return SizedBox(
                      height: 14,
                      width: 24,
                      child: Text(
                        _weekdayLabel(dayIndex),
                        style: TextStyle(
                          fontSize: 9,
                          color: subtleColor.withValues(alpha: 0.6),
                        ),
                      ),
                    );
                  }),
                ),
                // Grid columns (weeks)
                ...List.generate(weeks.length, (weekIndex) {
                  return Column(
                    children: List.generate(7, (dayIndex) {
                      final date = weeks[weekIndex][dayIndex];
                      if (date == null) {
                        return const SizedBox(width: 14, height: 14);
                      }
                      final dateStr =
                          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                      final hasEntry = entryDates.contains(dateStr);
                      final isToday = date == today;
                      final isFuture = date.isAfter(today);

                      return Container(
                        width: 14,
                        height: 14,
                        margin: const EdgeInsets.all(1),
                        decoration: BoxDecoration(
                          color: isFuture
                              ? Colors.transparent
                              : hasEntry
                                  ? goldColor.withValues(alpha: 0.8)
                                  : goldColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(2),
                          border: isToday
                              ? Border.all(color: goldColor, width: 1.5)
                              : null,
                        ),
                      );
                    }),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Legend
          Row(
            children: [
              Text(
                '少',
                style: TextStyle(fontSize: 10, color: subtleColor),
              ),
              const SizedBox(width: 4),
              ...List.generate(5, (i) {
                return Container(
                  width: 12,
                  height: 12,
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  decoration: BoxDecoration(
                    color: goldColor.withValues(alpha: 0.08 + i * 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              }),
              const SizedBox(width: 4),
              Text(
                '多',
                style: TextStyle(fontSize: 10, color: subtleColor),
              ),
              const Spacer(),
              _buildLegendItem('总计', '$totalDays 天', subtleColor),
              const SizedBox(width: 12),
              _buildLegendItem('连续', '$currentStreak 天', subtleColor),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, String value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label ',
          style: TextStyle(fontSize: 10, color: color),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 10,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  String _weekdayLabel(int index) {
    switch (index) {
      case 0:
        return '日';
      case 1:
        return '一';
      case 2:
        return '二';
      case 3:
        return '三';
      case 4:
        return '四';
      case 5:
        return '五';
      case 6:
        return '六';
      default:
        return '';
    }
  }

  List<List<DateTime?>> _buildWeeks(DateTime today) {
    // Start from 52 weeks ago, aligned to Sunday
    final startDate = today.subtract(Duration(days: today.weekday % 7 + 52 * 7));
    final weeks = <List<DateTime?>>[];

    DateTime current = startDate;
    for (int w = 0; w < 53; w++) {
      final week = <DateTime?>[];
      for (int d = 0; d < 7; d++) {
        if (current.isAfter(today)) {
          week.add(null); // future
        } else {
          week.add(current);
        }
        current = current.add(const Duration(days: 1));
      }
      weeks.add(week);
    }

    return weeks;
  }

  int _calcCurrentStreak(DateTime today) {
    int streak = 0;
    DateTime date = today;

    // 先检查今天是否有日记
    final todayStr =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    if (!entryDates.contains(todayStr)) {
      // 今天没写，从昨天开始计算
      date = date.subtract(const Duration(days: 1));
    }

    while (streak < 365) {
      final dateStr =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      if (!entryDates.contains(dateStr)) break;
      streak++;
      date = date.subtract(const Duration(days: 1));
    }
    return streak;
  }
}
