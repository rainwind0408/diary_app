import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';

class MoodDistributionChart extends StatelessWidget {
  final Map<String, int> moodStats;

  const MoodDistributionChart({super.key, required this.moodStats});

  // 水彩风格柔和色彩
  static const _colors = [
    Color(0xFFF5C6D0), // 粉色
    Color(0xFFA8D8EA), // 浅蓝
    Color(0xFFB5E8C3), // 浅绿
    Color(0xFFF5E6B8), // 浅黄
    Color(0xFFE8D5F5), // 浅紫
    Color(0xFFFFD4B8), // 浅橙
    Color(0xFFD4E8F5), // 天蓝
    Color(0xFFC8E6C9), // 薄荷
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkCardBackground : AppColors.cardBackground;
    final textColor = isDark ? AppColors.darkTitleText : AppColors.titleText;

    final sorted = moodStats.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = sorted.fold<int>(0, (sum, e) => sum + e.value);

    if (total == 0) return const SizedBox.shrink();

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
            '心情分布',
            style: AppTextStyles.cardTitle.copyWith(color: textColor),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 180,
            child: Row(
              children: [
                // 饼图
                Expanded(
                  flex: 3,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 32,
                      sections: List.generate(sorted.length, (i) {
                        final entry = sorted[i];
                        final percent = entry.value / total * 100;
                        return PieChartSectionData(
                          value: entry.value.toDouble(),
                          title: '${percent.round()}%',
                          titleStyle: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                          color: _colors[i % _colors.length],
                          radius: 50,
                        );
                      }),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // 图例
                Expanded(
                  flex: 2,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(sorted.take(6).length, (i) {
                      final entry = sorted[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: _colors[i % _colors.length],
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              entry.key,
                              style: const TextStyle(fontSize: 14),
                            ),
                            const Spacer(),
                            Text(
                              '${entry.value}',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? AppColors.darkSubtleText
                                    : AppColors.subtleText,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
