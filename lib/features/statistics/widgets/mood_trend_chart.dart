import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';

class MoodTrendChart extends StatelessWidget {
  final Map<String, List<String>> moodTrend;

  const MoodTrendChart({super.key, required this.moodTrend});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkCardBackground : AppColors.cardBackground;
    final goldColor = isDark ? AppColors.darkGoldAccent : AppColors.goldAccent;
    final subtleColor = isDark ? AppColors.darkSubtleText : AppColors.subtleText;

    // 统计每天的心情数量
    final entries = moodTrend.entries.toList();
    final maxCount = entries.fold<int>(
      0,
      (max, e) => e.value.length > max ? e.value.length : max,
    );

    // 找出每天最常见的心情
    String topMood(List<String> moods) {
      if (moods.isEmpty) return '';
      final count = <String, int>{};
      for (final m in moods) {
        count[m] = (count[m] ?? 0) + 1;
      }
      return count.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    }

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
          Text(
            '心情趋势',
            style: AppTextStyles.cardTitle.copyWith(
              color: isDark ? AppColors.darkTitleText : AppColors.titleText,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 160,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: (maxCount + 1).toDouble(),
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final mood = topMood(entries[group.x].value);
                      return BarTooltipItem(
                        mood.isNotEmpty ? '$mood ${rod.toY.toInt()}篇' : '${rod.toY.toInt()}篇',
                        TextStyle(
                          color: goldColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx >= entries.length) return const SizedBox();
                        // 只显示部分标签避免拥挤
                        if (entries.length > 7 && idx % 2 != 0) {
                          return const SizedBox();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            entries[idx].key,
                            style: TextStyle(
                              fontSize: 10,
                              color: subtleColor.withValues(alpha: 0.7),
                            ),
                          ),
                        );
                      },
                      reservedSize: 24,
                    ),
                  ),
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(show: false),
                gridData: const FlGridData(show: false),
                barGroups: List.generate(entries.length, (i) {
                  final count = entries[i].value.length.toDouble();
                  final top = topMood(entries[i].value);
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: count,
                        color: top.isNotEmpty
                            ? goldColor.withValues(alpha: 0.7)
                            : subtleColor.withValues(alpha: 0.2),
                        width: entries.length > 14 ? 8 : 14,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // 顶部心情 emoji 展示
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: entries.take(7).map((e) {
              final top = topMood(e.value);
              if (top.isEmpty) return const SizedBox();
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(top, style: const TextStyle(fontSize: 16)),
                  Text(
                    e.key,
                    style: TextStyle(
                      fontSize: 9,
                      color: subtleColor.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
