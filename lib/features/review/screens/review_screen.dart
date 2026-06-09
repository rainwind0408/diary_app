import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/repositories/diary_repository.dart';
import '../../diary_list/providers/diary_list_provider.dart';
import '../../statistics/providers/statistics_provider.dart';
import '../../statistics/widgets/mood_trend_chart.dart';
import '../../statistics/widgets/mood_distribution_chart.dart';
import '../../statistics/widgets/word_count_trend.dart';
import '../../statistics/widgets/tag_cloud_widget.dart';
import '../widgets/time_distribution.dart';
import '../widgets/yearly_heatmap.dart';
import '../widgets/calendar_view.dart';

class _StreakMilestone {
  final int days;
  final String emoji;
  final String title;
  final String subtitle;

  const _StreakMilestone(this.days, this.emoji, this.title, this.subtitle);
}

const _milestones = [
  _StreakMilestone(0, '📝', '开始你的第一天', '写下第一篇日记'),
  _StreakMilestone(3, '🌱', '坚持 3 天', '好习惯正在萌芽'),
  _StreakMilestone(7, '🔥', '坚持一周', '你已经养成了写作习惯'),
  _StreakMilestone(14, '⭐', '坚持两周', '持续创作的力量'),
  _StreakMilestone(30, '🏆', '坚持一个月', '了不起的坚持！'),
  _StreakMilestone(100, '💎', '坚持百天', '百日如一，非凡毅力'),
  _StreakMilestone(365, '👑', '坚持一年', '365天，你是写作大师'),
];

class ReviewScreen extends StatefulWidget {
  final ValueChanged<String>? onTagTapped;

  const ReviewScreen({super.key, this.onTagTapped});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  final DiaryRepository _repository = DiaryRepository();
  List<bool> _weekDays = [];
  bool _weekLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWeekData();
  }

  Future<void> _loadWeekData() async {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday % 7));
    final weekDays = List.filled(7, false);
    for (int i = 0; i < 7; i++) {
      final date = startOfWeek.add(Duration(days: i));
      final entryDays =
          await _repository.getEntryDatesInMonth(date.year, date.month);
      if (entryDays.contains(date.day)) {
        weekDays[i] = true;
      }
    }
    if (mounted) {
      setState(() {
        _weekDays = weekDays;
        _weekLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<StatisticsProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        // AppBar
        Container(
          padding: EdgeInsets.fromLTRB(
              20, MediaQuery.of(context).padding.top + 8, 20, 8),
          child: Row(
            children: [
              Text(
                '回顾',
                style: AppTextStyles.heading.copyWith(
                  color: isDark ? AppColors.darkTitleText : AppColors.titleText,
                ),
              ),
              const Spacer(),
              // 趋势天数切换
              _TrendDaysSelector(
                currentDays: provider.trendDays,
                onChanged: (days) => provider.setTrendDays(days),
              ),
            ],
          ),
        ),

        Expanded(
          child: provider.loading || _weekLoading
              ? Center(
                  child: CircularProgressIndicator(
                    color:
                        isDark ? AppColors.darkAccentPink : AppColors.accentPink,
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    // Streak section
                    _buildStreakCard(isDark, provider.streakDays),
                    const SizedBox(height: 20),

                    // This week section
                    _buildWeekCard(isDark),
                    const SizedBox(height: 20),

                    // Monthly stats
                    _buildMonthlyStatsCard(isDark, provider.monthlyStats),
                    const SizedBox(height: 20),

                    // Calendar view
                    const CalendarView(),
                    const SizedBox(height: 20),

                    // Mood trend chart
                    if (provider.moodTrend.values.any((v) => v.isNotEmpty)) ...[
                      MoodTrendChart(moodTrend: provider.moodTrend),
                      const SizedBox(height: 20),
                    ],

                    // Mood distribution chart
                    if (provider.moodDistribution.isNotEmpty) ...[
                      MoodDistributionChart(moodStats: provider.moodDistribution),
                      const SizedBox(height: 20),
                    ],

                    // Word count trend
                    if (provider.wordCountTrend.values.any((v) => v > 0)) ...[
                      WordCountTrend(trendData: provider.wordCountTrend),
                      const SizedBox(height: 20),
                    ],

                    // Time distribution
                    if (provider.timeDistribution.values.any((v) => v > 0)) ...[
                      TimeDistribution(timeStats: provider.timeDistribution),
                      const SizedBox(height: 20),
                    ],

                    // Yearly heatmap
                    if (provider.yearlyDates.isNotEmpty) ...[
                      YearlyHeatmap(entryDates: provider.yearlyDates),
                      const SizedBox(height: 20),
                    ],

                    // Tag cloud
                    if (provider.tagCloud.isNotEmpty)
                      TagCloudWidget(
                        tagData: provider.tagCloud,
                        onTagTapped: (tag) {
                          context.read<DiaryListProvider>().filterByTag(tag);
                          widget.onTagTapped?.call(tag);
                        },
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  _StreakMilestone _getMilestone(int streak) {
    _StreakMilestone current = _milestones.first;
    for (final m in _milestones) {
      if (streak >= m.days) {
        current = m;
      } else {
        break;
      }
    }
    return current;
  }

  _StreakMilestone? _getNextMilestone(int streak) {
    for (final m in _milestones) {
      if (streak < m.days) return m;
    }
    return null;
  }

  Widget _buildStreakCard(bool isDark, int streak) {
    final goldColor = isDark ? AppColors.darkAccentPink : AppColors.accentPink;
    final textColor = isDark ? AppColors.darkTitleText : AppColors.titleText;
    final subtleColor = isDark ? AppColors.darkSubtleText : AppColors.subtleText;
    final bgColor = isDark ? AppColors.darkCardBackground : AppColors.cardBackground;

    final milestone = _getMilestone(streak);
    final next = _getNextMilestone(streak);

    double progress = 1.0;
    String progressLabel = '已达成最高里程碑';
    if (next != null) {
      final prevDays = milestone.days;
      final nextDays = next.days;
      progress = (streak - prevDays) / (nextDays - prevDays);
      progressLabel = '距 ${next.title} 还有 ${nextDays - streak} 天';
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: isDark ? AppColors.darkCardShadow : AppColors.cardShadow,
      ),
      child: Column(
        children: [
          Text(
            milestone.emoji,
            style: TextStyle(fontSize: streak > 0 ? 40 : 32),
          ),
          const SizedBox(height: 12),
          Text(
            '$streak',
            style: TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: goldColor,
              fontFamily: 'MaShanZheng',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            milestone.title,
            style: AppTextStyles.body.copyWith(
              color: streak > 0 ? textColor : subtleColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            milestone.subtitle,
            style: AppTextStyles.label.copyWith(
              color: subtleColor.withValues(alpha: 0.7),
              fontSize: 13,
            ),
          ),
          if (streak > 0) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: subtleColor.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation<Color>(goldColor),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              progressLabel,
              style: TextStyle(fontSize: 11, color: subtleColor),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWeekCard(bool isDark) {
    final goldColor = isDark ? AppColors.darkAccentPink : AppColors.accentPink;
    final subtleColor = isDark ? AppColors.darkSubtleText : AppColors.subtleText;
    final bgColor = isDark ? AppColors.darkCardBackground : AppColors.cardBackground;
    final weekDayNames = ['日', '一', '二', '三', '四', '五', '六'];

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
            '本周写作',
            style: AppTextStyles.cardTitle.copyWith(
              color: isDark ? AppColors.darkTitleText : AppColors.titleText,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(7, (i) {
              final hasWritten = i < _weekDays.length && _weekDays[i];
              return Column(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: hasWritten ? goldColor : Colors.transparent,
                      border: Border.all(
                        color: hasWritten
                            ? goldColor
                            : subtleColor.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                    ),
                    child: hasWritten
                        ? Icon(Icons.check,
                            size: 18,
                            color: isDark
                                ? AppColors.darkCardBackground
                                : AppColors.cardBackground)
                        : null,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    weekDayNames[i],
                    style: TextStyle(fontSize: 12, color: subtleColor),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyStatsCard(bool isDark, Map<String, int> monthlyStats) {
    final goldColor = isDark ? AppColors.darkAccentPink : AppColors.accentPink;
    final subtleColor = isDark ? AppColors.darkSubtleText : AppColors.subtleText;
    final bgColor = isDark ? AppColors.darkCardBackground : AppColors.cardBackground;
    final count = monthlyStats['count'] ?? 0;
    final words = monthlyStats['total_words'] ?? 0;
    final now = DateTime.now();

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
            '${now.month}月统计',
            style: AppTextStyles.cardTitle.copyWith(
              color: isDark ? AppColors.darkTitleText : AppColors.titleText,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _StatItem(
                  icon: Icons.edit_note,
                  value: '$count',
                  label: '篇日记',
                  color: goldColor,
                  subtleColor: subtleColor,
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: subtleColor.withValues(alpha: 0.2),
              ),
              Expanded(
                child: _StatItem(
                  icon: Icons.text_fields,
                  value: words
                      .toString()
                      .replaceAllMapped(
                          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                          (m) => '${m[1]},'),
                  label: '总字数',
                  color: goldColor,
                  subtleColor: subtleColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TrendDaysSelector extends StatelessWidget {
  final int currentDays;
  final ValueChanged<int> onChanged;

  const _TrendDaysSelector({required this.currentDays, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final goldColor = isDark ? AppColors.darkAccentPink : AppColors.accentPink;
    final subtleColor = isDark ? AppColors.darkSubtleText : AppColors.subtleText;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: goldColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _DayButton(
            label: '7天',
            isSelected: currentDays == 7,
            onTap: () => onChanged(7),
            goldColor: goldColor,
            subtleColor: subtleColor,
          ),
          _DayButton(
            label: '14天',
            isSelected: currentDays == 14,
            onTap: () => onChanged(14),
            goldColor: goldColor,
            subtleColor: subtleColor,
          ),
          _DayButton(
            label: '30天',
            isSelected: currentDays == 30,
            onTap: () => onChanged(30),
            goldColor: goldColor,
            subtleColor: subtleColor,
          ),
        ],
      ),
    );
  }
}

class _DayButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color goldColor;
  final Color subtleColor;

  const _DayButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.goldColor,
    required this.subtleColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? goldColor : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isSelected ? Colors.white : subtleColor,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  final Color subtleColor;

  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    required this.subtleColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 24, color: color),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: color,
            fontFamily: 'MaShanZheng',
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 13, color: subtleColor)),
      ],
    );
  }
}
