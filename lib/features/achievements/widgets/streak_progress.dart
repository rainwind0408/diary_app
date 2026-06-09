import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';

class StreakProgress extends StatelessWidget {
  final int streakDays;
  final List<bool> weekDays;

  const StreakProgress({
    super.key,
    required this.streakDays,
    this.weekDays = const [],
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final goldColor = isDark ? AppColors.darkGoldAccent : AppColors.goldAccent;
    final textColor = isDark ? AppColors.darkTitleText : AppColors.titleText;
    final subtleColor = isDark ? AppColors.darkSubtleText : AppColors.subtleText;
    final bgColor = isDark ? AppColors.darkCardBackground : AppColors.cardBackground;

    final milestone = _getNextMilestone(streakDays);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: isDark ? AppColors.darkCardShadow : AppColors.cardShadow,
      ),
      child: Column(
        children: [
          // Fire icon
          Text(
            streakDays > 0 ? '🔥' : '📝',
            style: TextStyle(fontSize: streakDays > 0 ? 40 : 32),
          ),
          const SizedBox(height: 12),
          // Streak number
          Text(
            '$streakDays',
            style: TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: goldColor,
              fontFamily: 'MaShanZheng',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '连续写作天数',
            style: AppTextStyles.body.copyWith(
              color: streakDays > 0 ? textColor : subtleColor,
            ),
          ),
          // Progress bar
          if (milestone != null) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: streakDays / milestone.days,
                backgroundColor: subtleColor.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation<Color>(goldColor),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '距「${milestone.name}」还有 ${milestone.days - streakDays} 天',
              style: TextStyle(fontSize: 11, color: subtleColor),
            ),
          ],
          // Week progress
          if (weekDays.isNotEmpty) ...[
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(7, (i) {
                final has = i < weekDays.length && weekDays[i];
                return Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(right: 5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: has
                        ? goldColor
                        : goldColor.withValues(alpha: 0.15),
                  ),
                );
              }),
            ),
          ],
        ],
      ),
    );
  }

  _Milestone? _getNextMilestone(int streak) {
    const milestones = [
      _Milestone(3, '初心'),
      _Milestone(7, '坚持'),
      _Milestone(14, '毅力'),
      _Milestone(30, '习惯'),
      _Milestone(100, '传奇'),
    ];
    for (final m in milestones) {
      if (streak < m.days) return m;
    }
    return null;
  }
}

class _Milestone {
  final int days;
  final String name;
  const _Milestone(this.days, this.name);
}
