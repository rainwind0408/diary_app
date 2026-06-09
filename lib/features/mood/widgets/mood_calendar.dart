import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';

class MoodCalendar extends StatelessWidget {
  final DateTime month;
  final Map<int, String> dayMoods; // day -> emoji

  const MoodCalendar({
    super.key,
    required this.month,
    required this.dayMoods,
  });

  // 水彩色轮换（与 mini_calendar 统一）
  static const List<Color> _dayColors = [
    AppColors.pink,
    AppColors.blue,
    AppColors.green,
    AppColors.yellow,
    AppColors.purple,
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = isDark ? AppColors.darkAccentPink : AppColors.accentPink;
    final subtleColor = isDark ? AppColors.darkSubtleText : AppColors.subtleText;
    final bgColor = isDark ? AppColors.darkCardBackground : AppColors.cardBackground;
    final textColor = isDark ? AppColors.darkTitleText : AppColors.titleText;

    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final firstWeekday = DateTime(month.year, month.month, 1).weekday; // 1=Mon, 7=Sun
    final now = DateTime.now();
    final isCurrentMonth = now.year == month.year && now.month == month.month;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDark ? AppColors.darkCardShadow : AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.calendar_month, size: 18, color: accentColor),
              const SizedBox(width: 8),
              Text(
                '${month.year}年${month.month}月 心情日历',
                style: AppTextStyles.cardTitle.copyWith(
                  color: textColor,
                ),
              ),
              const Spacer(),
              Text(
                '${dayMoods.length} 天有记录',
                style: AppTextStyles.label.copyWith(color: subtleColor),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Weekday headers
          Row(
            children: List.generate(7, (i) {
              return Expanded(
                child: Center(
                  child: Text(
                    _weekdayName(i),
                    style: TextStyle(
                      fontSize: 11,
                      color: subtleColor.withValues(alpha: 0.6),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),

          // Calendar grid with colored cells
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1,
            ),
            itemCount: _getStartOffset(firstWeekday) + daysInMonth,
            itemBuilder: (context, index) {
              final offset = _getStartOffset(firstWeekday);
              if (index < offset) {
                return const SizedBox.shrink();
              }

              final day = index - offset + 1;
              final mood = dayMoods[day];
              final isToday = isCurrentMonth && day == now.day;
              final dayColor = _dayColors[day % _dayColors.length];

              return Container(
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: mood != null
                      ? dayColor.withValues(alpha: 0.35)
                      : dayColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: isToday
                      ? Border.all(color: accentColor, width: 1.5)
                      : null,
                ),
                child: Center(
                  child: mood != null
                      ? Text(mood, style: const TextStyle(fontSize: 16))
                      : Text(
                          '$day',
                          style: TextStyle(
                            fontSize: 12,
                            color: isToday ? accentColor : subtleColor.withValues(alpha: 0.4),
                            fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                ),
              );
            },
          ),

          // Legend: mood distribution
          if (dayMoods.isNotEmpty) ...[
            const SizedBox(height: 12),
            Divider(color: subtleColor.withValues(alpha: 0.1)),
            const SizedBox(height: 8),
            _buildMoodDistribution(dayMoods, subtleColor),
          ],
        ],
      ),
    );
  }

  int _getStartOffset(int firstWeekday) {
    return firstWeekday % 7;
  }

  String _weekdayName(int index) {
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

  Widget _buildMoodDistribution(Map<int, String> dayMoods, Color subtleColor) {
    final moodCount = <String, int>{};
    for (final mood in dayMoods.values) {
      moodCount[mood] = (moodCount[mood] ?? 0) + 1;
    }

    final sorted = moodCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Wrap(
      spacing: 12,
      runSpacing: 4,
      children: sorted.take(5).map((entry) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(entry.key, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 2),
            Text(
              '${entry.value}',
              style: TextStyle(
                fontSize: 11,
                color: subtleColor.withValues(alpha: 0.6),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}
