import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/models/diary_entry.dart';

class YearlyReport extends StatelessWidget {
  final int year;
  final List<DiaryEntry> entries;

  const YearlyReport({
    super.key,
    required this.year,
    required this.entries,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final goldColor = isDark ? AppColors.darkAccentPink : AppColors.accentPink;
    final subtleColor = isDark ? AppColors.darkSubtleText : AppColors.subtleText;
    final bgColor = isDark ? AppColors.darkCardBackground : AppColors.cardBackground;
    final borderColor = isDark ? AppColors.darkDividerLine : AppColors.dividerLine;

    final yearEntries =
        entries.where((e) => e.createdAt.year == year).toList();
    final totalEntries = yearEntries.length;
    final totalWords = yearEntries.fold(0, (sum, e) => sum + e.wordCount);
    final avgWords = totalEntries > 0 ? (totalWords / totalEntries).round() : 0;

    // Unique writing days
    final uniqueDays = yearEntries
        .map((e) => DateTime(e.createdAt.year, e.createdAt.month, e.createdAt.day))
        .toSet()
        .length;

    // Monthly distribution
    final monthlyCount = List.filled(12, 0);
    for (final entry in yearEntries) {
      monthlyCount[entry.createdAt.month - 1]++;
    }
    final maxMonthly = monthlyCount.reduce((a, b) => a > b ? a : b);

    // Most active month
    final mostActiveMonth = monthlyCount.indexOf(maxMonthly) + 1;

    // Top moods
    final moodCount = <String, int>{};
    for (final entry in yearEntries) {
      if (entry.mood.isNotEmpty) {
        moodCount[entry.mood] = (moodCount[entry.mood] ?? 0) + 1;
      }
    }
    final topMoods = moodCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Top tags
    final tagCount = <String, int>{};
    for (final entry in yearEntries) {
      for (final tag in entry.tags) {
        tagCount[tag] = (tagCount[tag] ?? 0) + 1;
      }
    }
    final topTags = tagCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

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
              Icon(Icons.auto_stories, size: 18, color: goldColor),
              const SizedBox(width: 8),
              Text(
                '$year 年度报告',
                style: AppTextStyles.cardTitle.copyWith(
                  color: isDark ? AppColors.darkTitleText : AppColors.titleText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Stats grid
          Row(
            children: [
              _buildStatCard('日记篇数', '$totalEntries', Icons.edit_note, goldColor, subtleColor, borderColor),
              const SizedBox(width: 8),
              _buildStatCard('总字数', _formatNumber(totalWords), Icons.text_fields, goldColor, subtleColor, borderColor),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildStatCard('写作天数', '$uniqueDays', Icons.calendar_today, goldColor, subtleColor, borderColor),
              const SizedBox(width: 8),
              _buildStatCard('篇均字数', '$avgWords', Icons.analytics, goldColor, subtleColor, borderColor),
            ],
          ),
          const SizedBox(height: 16),

          // Monthly distribution
          Text(
            '月度分布',
            style: AppTextStyles.label.copyWith(
              color: isDark ? AppColors.darkTitleText : AppColors.titleText,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 80,
            child: Row(
              children: List.generate(12, (i) {
                final count = monthlyCount[i];
                final height = maxMonthly > 0 ? (count / maxMonthly * 60) : 0.0;
                final isMostActive = i + 1 == mostActiveMonth;

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          count > 0 ? '$count' : '',
                          style: TextStyle(
                            fontSize: 9,
                            color: subtleColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          height: height,
                          decoration: BoxDecoration(
                            color: isMostActive
                                ? goldColor
                                : goldColor.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${i + 1}月',
                          style: TextStyle(
                            fontSize: 9,
                            color: isMostActive
                                ? goldColor
                                : subtleColor.withValues(alpha: 0.6),
                            fontWeight: isMostActive ? FontWeight.w600 : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
          if (mostActiveMonth > 0 && maxMonthly > 0) ...[
            const SizedBox(height: 8),
            Text(
              '最活跃月份：$mostActiveMonth月（$maxMonthly 篇）',
              style: TextStyle(
                fontSize: 11,
                color: subtleColor,
              ),
            ),
          ],

          // Top moods
          if (topMoods.isNotEmpty) ...[
            const SizedBox(height: 16),
            Divider(color: borderColor.withValues(alpha: 0.3)),
            const SizedBox(height: 8),
            Text(
              '心情排行',
              style: AppTextStyles.label.copyWith(
                color: isDark ? AppColors.darkTitleText : AppColors.titleText,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: topMoods.take(5).map((mood) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: goldColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(mood.key, style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 4),
                      Text(
                        '${mood.value}次',
                        style: TextStyle(
                          fontSize: 11,
                          color: subtleColor,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],

          // Top tags
          if (topTags.isNotEmpty) ...[
            const SizedBox(height: 16),
            Divider(color: borderColor.withValues(alpha: 0.3)),
            const SizedBox(height: 8),
            Text(
              '热门标签',
              style: AppTextStyles.label.copyWith(
                color: isDark ? AppColors.darkTitleText : AppColors.titleText,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: topTags.take(8).map((tag) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: goldColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: goldColor.withValues(alpha: 0.2)),
                  ),
                  child: Text(
                    '#${tag.key} (${tag.value})',
                    style: TextStyle(
                      fontSize: 12,
                      color: goldColor,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color goldColor,
    Color subtleColor,
    Color borderColor,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: goldColor.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: goldColor),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: goldColor,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: subtleColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatNumber(int number) {
    if (number >= 10000) {
      return '${(number / 10000).toStringAsFixed(1)}万';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}k';
    }
    return '$number';
  }
}
