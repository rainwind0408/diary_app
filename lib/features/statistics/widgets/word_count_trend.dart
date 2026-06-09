import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';

class WordCountTrend extends StatelessWidget {
  final Map<String, int> trendData;

  const WordCountTrend({super.key, required this.trendData});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkCardBackground : AppColors.cardBackground;
    final goldColor = isDark ? AppColors.darkGoldAccent : AppColors.goldAccent;
    final subtleColor = isDark ? AppColors.darkSubtleText : AppColors.subtleText;
    final textColor = isDark ? AppColors.darkTitleText : AppColors.titleText;

    final entries = trendData.entries.toList();
    final maxValue = entries.fold<int>(
      0,
      (max, e) => e.value > max ? e.value : max,
    );

    final totalWords = entries.fold<int>(0, (sum, e) => sum + e.value);
    final avgWords = entries.isNotEmpty ? totalWords ~/ entries.length : 0;

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
                '字数趋势',
                style: AppTextStyles.cardTitle.copyWith(color: textColor),
              ),
              const Spacer(),
              Text(
                '日均 $avgWords 字',
                style: AppTextStyles.label.copyWith(
                  color: subtleColor.withValues(alpha: 0.7),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 150,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: maxValue > 0 ? maxValue * 1.2 : 100,
                lineTouchData: LineTouchData(
                  enabled: true,
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (spots) {
                      return spots.map((spot) {
                        return LineTooltipItem(
                          '${spot.y.toInt()}字',
                          TextStyle(
                            color: goldColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        );
                      }).toList();
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
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxValue > 0 ? maxValue / 3 : 50,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: subtleColor.withValues(alpha: 0.1),
                      strokeWidth: 1,
                    );
                  },
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: List.generate(entries.length, (i) {
                      return FlSpot(i.toDouble(), entries[i].value.toDouble());
                    }),
                    isCurved: true,
                    preventCurveOverShooting: true,
                    color: goldColor,
                    barWidth: 2.5,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, bar, index) {
                        return FlDotCirclePainter(
                          radius: 3,
                          color: goldColor,
                          strokeWidth: 1.5,
                          strokeColor: bgColor,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: goldColor.withValues(alpha: 0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
